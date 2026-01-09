--!optimize 2

local Packages = script.Parent.Parent.Packages
local Log = require(Packages.Log)

local ConfigProcessor = {}

-- Module state: cached aliases and config instance ID
local cachedAliases = nil
local cachedUseStringAliases = nil
local cachedConfigId = nil

@native
local function transformRequires(src, aliasToPath)
	local i = 1
	local n = #src
	local out = {}
	local outLen = 0

	local function emit(s)
		outLen += 1
		out[outLen] = s
	end

	local function peek(k)
		return src:sub(i + (k or 0), i + (k or 0))
	end

	local function readIdentifier()
		local start = i
		while i <= n and src:sub(i, i):match("[%w_]") do
			i += 1
		end
		return src:sub(start, i - 1)
	end

	while i <= n do
		local c = src:sub(i, i)

		-- line comment
		if c == "-" and src:sub(i + 1, i + 1) == "-" then
			local start = i
			i += 2
			while i <= n and src:sub(i, i) ~= "\n" do
				i += 1
			end
			emit(src:sub(start, i - 1))

		-- identifier
		elseif c:match("[%a_]") then
			local startI = i
			local id = readIdentifier()

			if id == "require" then
				local callStart = startI
				local probeI = i
				local matched = false
				local replacement

				-- skip spaces/tabs
				while probeI <= n do
					local ch = src:sub(probeI, probeI)
					if ch == " " or ch == "\t" or ch == "\r" then
						probeI += 1
					else
						break
					end
				end

				local hasParen = false
				if src:sub(probeI, probeI) == "(" then
					hasParen = true
					probeI += 1
					while probeI <= n do
						local ch = src:sub(probeI, probeI)
						if ch == " " or ch == "\t" or ch == "\r" then
							probeI += 1
						else
							break
						end
					end
				end

				local q = src:sub(probeI, probeI)
				if q == '"' or q == "'" or q == "`" then
					probeI += 1
					local strStart = probeI

					while probeI <= n and src:sub(probeI, probeI) ~= q do
						probeI += 1
					end

					if probeI <= n then
						local str = src:sub(strStart, probeI - 1)
						probeI += 1

						if str:sub(1, 1) == "@" and not str:match("^@self") then
							if hasParen then
								while probeI <= n do
									local ch = src:sub(probeI, probeI)
									if ch == " " or ch == "\t" or ch == "\r" then
										probeI += 1
									else
										break
									end
								end
								if src:sub(probeI, probeI) == ")" then
									probeI += 1
								end
							end

							replacement = "require(" .. aliasToPath(str) .. ")"
							matched = true
						end
					end
				end

				if matched then
					emit(replacement)
					i = probeI
				else
					-- emit original text verbatim
					emit(src:sub(callStart, i - 1))
				end
			else
				emit(id)
			end
		else
			emit(c)
			i += 1
		end
	end

	return table.concat(out)
end

@native
local function isValidIdentifier(name)
	return name:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

@native
local function emitAccess(base, name)
	if isValidIdentifier(name) then
		return base .. "." .. name
	else
		return base .. '["' .. name .. '"]'
	end
end

@native
local function aliasToPath(str, aliases, cachedUseStringAliases)
	-- "@foo/x/../test  /"
	local body = str:sub(2)

	local first, rest = body:match("^([^/]+)(.*)")
	local base = aliases[first] or ("game." .. first)

	if cachedUseStringAliases then
		return `"{base}{rest}"`
	end

	local result = base

	for segment in rest:gmatch("/([^/]*)") do
		if segment == "" then
		-- ignore empty (trailing slash)
		elseif segment == "." then
		-- no-op
		elseif segment == ".." then
			result ..= ".Parent"
		else
			result = emitAccess(result, segment)
		end
	end

	return result
end

-- Helper: Find the rojo folder instance via instanceMap
local function findRojoFolder(instanceMap)
	for instance, id in pairs(instanceMap.fromInstances) do
		if instance.Name == "rojo" and instance.Parent == game then
			return instance
		end
	end
	return nil
end

-- Helper: Find config source and ID from patch or tree
local function findConfigSourceAndId(patch, instanceMap)
	local rojoFolder = findRojoFolder(instanceMap)
	if not rojoFolder then
		return nil, nil
	end

	local rojoId = instanceMap.fromInstances[rojoFolder]

	-- Check patch.added for new config
	for id, virtualInstance in pairs(patch.added) do
		if
			virtualInstance.Name == "config"
			and virtualInstance.ClassName == "ModuleScript"
			and virtualInstance.Parent == rojoId
		then
			if virtualInstance.Properties and virtualInstance.Properties.Source then
				return virtualInstance.Properties.Source, id
			end
		end
	end

	-- Check patch.updated for changed config
	for _, update in ipairs(patch.updated) do
		local instance = instanceMap.fromIds[update.id]
		if
			instance
			and instance.Name == "config"
			and instance.ClassName == "ModuleScript"
			and instance.Parent == rojoFolder
		then
			if update.changedProperties and update.changedProperties.Source then
				return update.changedProperties.Source, update.id
			end
		end
	end

	-- Check tree for existing config
	local configInstance = rojoFolder:FindFirstChild("config")
	if configInstance and configInstance:IsA("ModuleScript") then
		return configInstance.Source, instanceMap.fromInstances[configInstance]
	end

	return nil, nil
end

-- Helper: Parse config source to extract roblox.aliases
local function parseConfig(source)
	if not source or source == "" then
		Log.warn("ConfigProcessor: Config source is empty")
		return nil
	end

	local success, configTable = pcall(function()
		return loadstring(source)()
	end)

	if not success then
		Log.warn("ConfigProcessor: Failed to parse config: {}", tostring(configTable))
		return nil
	end

	if not configTable or type(configTable) ~= "table" then
		Log.warn("ConfigProcessor: Config did not return a table")
		return nil
	end

	if not configTable.roblox or not configTable.roblox.aliases then
		Log.warn("ConfigProcessor: Config missing roblox.aliases")
		return nil
	end

	return configTable.roblox
end

-- Helper: Transform source by replacing @alias patterns
local function transformSource(source: string, aliases, cachedUseStringAliases)
	if not source or not aliases then
		return source
	end

	return transformRequires(source, function(s)
		return aliasToPath(s, aliases, cachedUseStringAliases)
	end)
end

-- Main function: Transform patch in-place
function ConfigProcessor.transformPatch(patch, instanceMap)
	if not patch or not instanceMap then
		return
	end

	-- Find config source and ID
	local configSource, configId = findConfigSourceAndId(patch, instanceMap)

	-- Update cache if config changed
	if configSource and configId ~= cachedConfigId then
		local config = parseConfig(configSource)
		if config then
			cachedAliases = config.aliases
			cachedUseStringAliases = config.use_string_aliases
			cachedConfigId = configId
			Log.trace("ConfigProcessor: Updated aliases cache")
		else
			Log.warn("ConfigProcessor: Parse failed; using previous aliases")
		end
	end

	-- If no aliases, nothing to transform
	if not cachedAliases then
		return
	end

	-- Transform scripts in patch.added
	for id, virtualInstance in pairs(patch.added) do
		if
			virtualInstance.ClassName == "ModuleScript"
			or virtualInstance.ClassName == "LocalScript"
			or virtualInstance.ClassName == "Script"
		then
			if virtualInstance.Properties and virtualInstance.Properties.Source then
				virtualInstance.Properties.Source.String =
					transformSource(virtualInstance.Properties.Source.String, cachedAliases, cachedUseStringAliases)
			end
		end
	end

	-- Transform scripts in patch.updated
	for _, update in ipairs(patch.updated) do
		if update.changedProperties and update.changedProperties.Source then
			local instance = instanceMap.fromIds[update.id]
			if instance and (instance:IsA("ModuleScript") or instance:IsA("LocalScript") or instance:IsA("Script")) then
				update.changedProperties.Source.String =
					transformSource(update.changedProperties.Source.String, cachedAliases, cachedUseStringAliases)
			end
		end
	end
end

return ConfigProcessor
