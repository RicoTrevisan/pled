# Gemini Context: Pled - Bubble.io Plugin CLI

## Project Overview

Pled is a command-line interface (CLI) tool built with Elixir to streamline the development of plugins for Bubble.io. It provides a set of commands to manage the entire plugin development lifecycle, from fetching plugin data from Bubble.io to pushing local changes back to the platform.

The tool is designed to be used on a per-plugin basis, with environment variables configured for each plugin's directory.

**Key Technologies:**

*   **Elixir:** The core language for the CLI tool.
*   **Req:** An HTTP client for making requests to the Bubble.io API.
*   **Burrito:** A tool for packaging the Elixir application into a single executable.
*   **FileSystem:** A library for watching file system events.
*   **Jason:** A JSON library for Elixir.

**Architecture:**

The application is structured as a standard Elixir Mix project. The main entry point is the `Pled` module, which parses command-line arguments and delegates to the appropriate command module in the `lib/pled/commands` directory. The `Pled.BubbleApi` module encapsulates all interactions with the Bubble.io API.

## Building and Running

**Dependencies:**

*   Elixir >= 1.18
*   mix (Elixir's build tool)

**Installation:**

1.  Clone the repository.
2.  Install dependencies: `mix deps.get`
3.  Build the project: `mix compile`

**Running the CLI:**

The CLI can be run using `mix run` or by building a release executable.

```bash
# Run with mix
mix run pled -- --help

# Build a release executable
mix release

# Run the release executable
./_build/dev/rel/pled/bin/pled --help
```

**Available Commands:**

*   `pull`: Fetches the plugin data from Bubble.io.
*   `push`: Pushes local changes to Bubble.io.
*   `encode`: Encodes the plugin files.
*   `upload <file_path>`: Uploads a file to Bubble.io.
*   `watch`: Watches for file changes and automatically pushes them.
*   `init`: Initializes a new plugin directory.
*   `help`: Displays the help message.

## Development Conventions

**Testing:**

*   Tests are located in the `test` directory.
*   Run tests with `mix test`.
*   Integration tests are excluded by default. To run them, you'll need to modify the `test` alias in `mix.exs`.

**Environment Variables:**

The following environment variables are required for interacting with the Bubble.io API:

*   `COOKIE`: Your Bubble.io authentication cookie.
*   `PLUGIN_ID`: The ID of the plugin you are working on.

It is recommended to use a tool like `direnv` to manage these variables on a per-directory basis.

**Code Style:**

The project uses the default Elixir formatter. Run `mix format` to format the code.
