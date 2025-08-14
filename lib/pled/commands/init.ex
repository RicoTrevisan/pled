defmodule Pled.Commands.Init do
  @moduledoc """
  Initialize a new Pled project structure
  """

  def run(opts) do
    IO.puts("Initializing Pled project...")

    with :ok <- create_envrc(),
         :ok <- create_gitignore(),
         :ok <- create_llm_md(),
         :ok <- create_lib_directory(),
         :ok <- create_package_json(),
         :ok <- create_index_js(opts) do
      react? = Keyword.get(opts, :react, false)

      IO.puts("""
      ✓ Project initialized successfully!

      Next steps:
      1. Edit .envrc file with your PLUGIN_ID and COOKIE values
      2. Run 'source .envrc' to load environment variables
      3. Run 'pled pull' to fetch your plugin from Bubble.io
      """)

      if react?,
        do:
          IO.write(
            "4. run `npm install react react-dom --prefix lib` to install the React libraries"
          )

      :ok
    else
      error -> error
    end
  end

  defp create_envrc do
    envrc_content = """
    # for more information on `direnv`, see: https://direnv.net

    # grab the Bubble ID of your plugin
    export PLUGIN_ID=

    # grab the cookies from a Bubble session
    export COOKIE=""

    # add the url of the Bubble app that you use to test this plugin
    # if your app has username and password, you can add it
    # `https://USERNAME:PASSWORD@BUBBLE_ID.bubbleapps.io/version-test/PAGE_NAME`
    export TEST_URL=
    """

    case File.exists?(".envrc") do
      true ->
        IO.puts("⚠ .envrc already exists, skipping...")
        :ok

      false ->
        File.write(".envrc", envrc_content)
        IO.puts("✓ Created .envrc")
        :ok
    end
  end

  defp create_llm_md do
    content = """
    # working with Pled

    ## Essential Context

    - Project purpose: this is a Bubble.io plugin
    - Core workflow: Pull → Edit locally → Push back to Bubble.
    - You can run `pled watch` to automatically encode and push when there are changes to the `src/` directory.
    - File structure: src/ contains decoded human-readable files, dist/ contains encoded Bubble JSON, lib/ contains any libraries that you might want to add to your project

    ## Key Commands & Usage

    - Environment setup requirements (PLUGIN_ID, COOKIE, TEST_URL)
    - Main commands: pull, push, watch, encode, init
    - Testing commands and patterns

    ## Development Guidelines

    - when changing `lib/index.js`, run `npm run build` in the `lib/` directory, then rename the `lib/dist.js` file to the latest version (start at `dist-v01.js` and go up from there), the run `pled upload lib/dist-vVERSION.js`
    - when making changes to an element's `initialize.js` or `update.js`, in order to verify if the changes are working, use the Playwright MCP server and open the page listed in env var "TEST_URL"
    - in initialize and update, you never have to add the standard bubble `function(properties...)`. Pled will do that automatically.
    - `initialize.js` runs with `instance` and `context`
    - `update.js` runs with `instance`, `properties`, and `context`
    - if a `shared_keys` is `secure`, it is never available in the elements, only in server-side actions.

    """

    case File.exists?("llm.md") do
      true ->
        existing_content = File.read!("llm.md")

        if String.contains?(existing_content, "# working with Pled") do
          IO.puts("llm.md already contains # working with Pled, skipping...")
          :ok
        else
          File.write("llm.md", existing_content <> content)
          IO.puts("✓ Updated llm.md")
          :ok
        end

      false ->
        File.write("llm.md", content)
        IO.puts("✓ Created llm.md")
        :ok
    end
  end

  defp create_gitignore do
    gitignore_content = """
    .envrc
    lib/node_modules
    lib/dist*
    dist*
    """

    case File.exists?(".gitignore") do
      true ->
        existing_content = File.read!(".gitignore")

        if String.contains?(existing_content, ".envrc") do
          IO.puts("⚠ .gitignore already contains .envrc, skipping...")
          :ok
        else
          File.write(".gitignore", existing_content <> gitignore_content)
          IO.puts("✓ Updated .gitignore")
          :ok
        end

      false ->
        File.write(".gitignore", gitignore_content)
        IO.puts("✓ Created .gitignore")
        :ok
    end
  end

  defp create_lib_directory do
    case File.mkdir_p("lib") do
      :ok ->
        IO.puts("✓ Created lib/ directory")
        :ok

      {:error, reason} ->
        IO.puts("✗ Failed to create lib/ directory: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_package_json do
    lib_path = "lib"
    package_json_path = Path.join(lib_path, "package.json")

    case File.exists?(package_json_path) do
      true ->
        IO.puts("⚠ lib/package.json already exists, skipping npm init...")
        update_existing_package_json(package_json_path)

      false ->
        package_json = """
        {
          "name": "my-plugin-package",
          "version": "0.0.1",
          "description": "",
          "main": "index.js",
          "scripts": {
              "build": "esbuild index.js --bundle --minify --outfile=dist.js"
          },
          "keywords": [],
          "author": "",
          "license": "ISC"
        }

        """

        File.write(package_json_path, package_json)
    end
  end

  defp update_existing_package_json(package_json_path) do
    case File.read(package_json_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, json} ->
            scripts = Map.get(json, "scripts", %{})

            updated_scripts =
              Map.put(scripts, "build", "esbuild index.js --bundle --minify --outfile=dist.js")

            updated_json = Map.put(json, "scripts", updated_scripts)

            case Jason.encode(updated_json, pretty: true) do
              {:ok, updated_content} ->
                File.write(package_json_path, updated_content)
                IO.puts("✓ Added build script to lib/package.json")
                :ok

              {:error, reason} ->
                IO.puts("✗ Failed to encode JSON: #{inspect(reason)}")
                {:error, reason}
            end

          {:error, reason} ->
            IO.puts("✗ Failed to parse package.json: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts("✗ Failed to read package.json: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_index_js(opts) do
    index_js_path = Path.join("lib", "index.js")

    case File.exists?(index_js_path) do
      true ->
        IO.puts("⚠ lib/index.js already exists, skipping...")
        :ok

      false ->
        index_context =
          case Keyword.get(opts, :react, false) do
            true -> index_js_content(:react)
            false -> index_js_content()
          end

        File.write(index_js_path, index_context)
        IO.puts("✓ Created lib/index.js")
        :ok
    end
  end

  defp index_js_content(:react) do
    """
    import { createElement } from "react";
    import ReactDOM from "react-dom";
    import { createRoot } from "react-dom/client";

    // create a object to store those modules, for example
    // window.MyPluginModules = { createElement, ReactDOM, createRoot };

    """
  end

  defp index_js_content do
    """
    """
  end
end
