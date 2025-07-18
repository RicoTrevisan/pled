defmodule Pled.CLI do
  @moduledoc """
  Command line interface for Pled.
  """
  require Logger

  alias Pled.Commands.Encoder
  alias Pled.Commands.Decoder

  def parse_args(args) do
    case args do
      ["pull"] -> {:pull, []}
      ["pull" | opts] -> {:pull, opts}
      ["push"] -> {:push, []}
      ["push" | opts] -> {:push, opts}
      ["encode"] -> {:encode, []}
      [] -> {:help, []}
      _ -> {:help, []}
    end
  end

  def handle_command({:encode, _opts}) do
    IO.puts("Encoding files")

    Encoder.encode()
    System.halt(0)
  end

  def handle_command({:pull, _opts}) do
    IO.puts("Fetching plugin from Bubble.io...")
    IO.puts("Wiping src directory...")

    case File.rm_rf("src") do
      {:ok, files_and_directory} -> IO.puts("removed #{inspect(files_and_directory)}")
      {:error, reason, _file} -> Logger.error(reason)
    end

    case Pled.BubbleApi.fetch_plugin() do
      {:ok, plugin_data} ->
        output_dir = "src"
        File.mkdir_p!(output_dir)

        plugin_file = Path.join(output_dir, "plugin.json")
        json_content = Jason.encode!(plugin_data, pretty: true)

        case File.write(plugin_file, json_content) do
          :ok ->
            Decoder.decode(plugin_data, File.cwd!())
            IO.puts(" Plugin data saved to #{plugin_file}")
            System.halt(0)

          {:error, reason} ->
            IO.puts(" Failed to save plugin data: #{reason}")
            System.halt(1)
        end

      {:error, reason} ->
        IO.puts(" Failed to fetch plugin: #{reason}")
        System.halt(1)
    end
  end

  def handle_command({:push, _opts}) do
    IO.puts("Encoding src/ files into dist/")

    Encoder.encode()
    Pled.BubbleApi.save_plugin()
    System.halt(0)
  end

  def handle_command({:help, _opts}) do
    IO.puts("""
    Pled - Bubble.io Plugin Development Tool
    version 0.1.2

    Usage:
      pled pull    Fetch plugin from Bubble.io and save to src/plugin.json
      pled push    Upload plugin to Bubble.io (not yet implemented)
      pled encode  Packages and encodes dist/plugin.json file without uploading it

    Environment Variables:
      PLUGIN_ID    The ID of the plugin to fetch
      COOKIE       Authentication cookie for Bubble.io
    """)

    System.halt(0)
  end
end
