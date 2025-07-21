defmodule Pled.Commands.Pull do
  require Logger
  alias Pled.Commands.Decoder

  def run() do
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
end
