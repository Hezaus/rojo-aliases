<div align="center">
    <a href="https://rojo.space"><img src="assets/brand_images/logo-512.png" alt="Rojo" height="217" /></a>
</div>

<div>&nbsp;</div>

<div align="center">
    <a href="https://github.com/rojo-rbx/rojo/actions"><img src="https://github.com/rojo-rbx/rojo/workflows/CI/badge.svg" alt="Actions status" /></a>
    <a href="https://crates.io/crates/rojo"><img src="https://img.shields.io/crates/v/rojo.svg?label=latest%20release" alt="Latest server version" /></a>
    <a href="https://rojo.space/docs"><img src="https://img.shields.io/badge/docs-website-brightgreen.svg" alt="Rojo Documentation" /></a>
</div>

<hr />

**Rojo** is a tool designed to enable Roblox developers to use professional-grade software engineering tools.

With Rojo, it's possible to use industry-leading tools like **Visual Studio Code** and **Git**.

Rojo is designed for power users who want to use the best tools available for building games, libraries, and plugins.

## Features

Rojo enables:

-   Working on scripts and models from the filesystem, in your favorite editor
-   Versioning your game, library, or plugin using Git or another VCS
-   Streaming `rbxmx` and `rbxm` models into your game in real time
-   Packaging and deploying your project to Roblox.com from the command line

In the future, Rojo will be able to:

-   Sync instances from Roblox Studio to the filesystem
-   Automatically convert your existing game to work with Rojo
-   Import custom instances like MoonScript code

## Aliases Support (Fork)

This fork adds support for **aliases** in Rojo, available on the `uplift-syncback-release-aliases` branch.

> ⚠️ **Note**: This feature was vibecoded with care to solve my own problem. It may have rough edges, but it works for the use case it was built for. Use at your own discretion! (Also, this README was vibecoded too........)

### Setup Instructions

To use aliases support, follow these steps:

#### 1. Create a `.config.luau` file at your project root

Define your Luau and Roblox aliases:

```luau
return {
  luau = {
    aliases = {
      lune = "~/.lune/.typedefs/0.10.4/",
      test = "./src/test",
      src = "./src",
    },
  },

  roblox = {
    use_string_aliases = false,

    aliases = {
      test = "game.ReplicatedStorage.test",
      src = "game.ReplicatedStorage",
    },
  },
}
```

#### 2. Update your `.project.json` file

Include the Rojo configuration that references your `.config.luau` file:

```json
{
    "name": "test",

    "tree": {
        "$className": "DataModel",

        "rojo": {
            "$className": "Configuration",

            "config": {
                "$path": ".config.luau"
            }
        },

        "ReplicatedStorage": {
            "$path": "./src/"
        }
    }
}
```

The `roblox.aliases` defined in `.config.luau` will be used when syncing your project.
`use_string_aliases` is an option to keep as string when syncing

## [Documentation](https://rojo.space/docs)

Documentation is hosted in the [rojo.space repository](https://github.com/rojo-rbx/rojo.space).

## Contributing

Check out our [contribution guide](CONTRIBUTING.md) for detailed instructions for helping work on Rojo!

Pull requests are welcome!

Rojo supports Rust 1.70.0 and newer. The minimum supported version of Rust is based on the latest versions of the dependencies that Rojo has.

## License

Rojo is available under the terms of the Mozilla Public License, Version 2.0. See [LICENSE.txt](LICENSE.txt) for details.
