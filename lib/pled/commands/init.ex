defmodule Pled.Commands.Init do
  @moduledoc """
  Initialize a new Pled project structure
  """

  def run(opts) do
    IO.puts("Initializing Pled project...")

    with :ok <- create_envrc(),
         :ok <- create_gitignore(),
         :ok <- create_agents_md(),
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

  defp create_agents_md do
    content = File.read!("priv/AGENTS.md.template")

    case File.exists?("AGENTS.md") do
      true ->
        existing_content = File.read!("AGENTS.md")

        if String.contains?(existing_content, "# working with Pled") do
          IO.puts("AGENTS.md already contains # working with Pled, skipping...")
          :ok
        else
          File.write("AGENTS.md", existing_content <> content)
          IO.puts("✓ Updated AGENTS.md")
          :ok
        end

      false ->
        File.write("AGENTS.md", content)
        IO.puts("✓ Created AGENTS.md")
        :ok
    end
  end

  defp create_gitignore do
    gitignore_content = """
    .envrc
    .src.json
    lib/node_modules
    lib/dist*
    dist*
    """

    case File.exists?(".gitignore") do
      true ->
        existing_content = File.read!(".gitignore")

        entries_to_add = String.split(gitignore_content, "\n", trim: true)

        missing_entries =
          Enum.filter(entries_to_add, fn entry ->
            not String.contains?(existing_content, entry)
          end)

        if missing_entries == [] do
          IO.puts("⚠ .gitignore already contains all required entries, skipping...")
          :ok
        else
          new_content = existing_content <> "\n" <> Enum.join(missing_entries, "\n") <> "\n"
          File.write(".gitignore", new_content)

          IO.puts(
            "✓ Updated .gitignore with missing entries: #{Enum.join(missing_entries, ", ")}"
          )

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
