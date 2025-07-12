defmodule Pled.CLI do
  @moduledoc """
  Command line interface for Pled.
  """
  alias Pled.Commands.Encoder
  alias Pled.Commands.Decoder

  def main(_args) do
    # Use Burrito's argument parsing for compiled binaries
    args = Burrito.Util.Args.argv()

    args
    |> parse_args()
    |> handle_command()
  end

  defp parse_args(args) do
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

  defp handle_command({:encode, _opts}) do
    IO.puts("Encoding files")

    Encoder.encode()
  end

  defp handle_command({:pull, _opts}) do
    IO.puts("Fetching plugin from Bubble.io...")

    case Pled.BubbleApi.fetch_plugin() do
      {:ok, plugin_data} ->
        output_dir = "src"
        File.mkdir_p!(output_dir)

        plugin_file = Path.join(output_dir, "plugin.json")
        json_content = Jason.encode!(plugin_data, pretty: true)

        case File.write(plugin_file, json_content) do
          :ok ->
            Decoder.decode(plugin_data)
            IO.puts(" Plugin data saved to #{plugin_file}")

          {:error, reason} ->
            IO.puts(" Failed to save plugin data: #{reason}")
            System.halt(1)
        end

      {:error, reason} ->
        IO.puts(" Failed to fetch plugin: #{reason}")
        System.halt(1)
    end
  end

  defp handle_command({:push, _opts}) do
    IO.puts("Encoding src/ files into dist/")
    # System.halt(1)
    Encoder.encode()
    Pled.BubbleApi.save_plugin()
  end

  defp handle_command({:help, _opts}) do
    IO.puts("""
    Pled - Bubble.io Plugin Development Tool

    Usage:
      pled pull    Fetch plugin from Bubble.io and save to src/plugin.json
      pled push    Upload plugin to Bubble.io (not yet implemented)

    Environment Variables:
      PLUGIN_ID    The ID of the plugin to fetch
      COOKIE       Authentication cookie for Bubble.io
    """)
  end
end
