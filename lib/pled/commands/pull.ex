defmodule Pled.Commands.Pull do
  require Logger
  alias Pled.Commands.Decoder

  def run(opts) do
    IO.puts("Fetching plugin from Bubble.io...")

    wipe? = Keyword.get(opts, :wipe, false)

    if wipe? do
      IO.puts("Wiping src and dist directories...")

      with {:ok, dist} <- File.rm_rf("dist"),
           {:ok, src} <- File.rm_rf("src") do
        IO.puts("removed:")
        Enum.each(dist, &IO.puts(&1))
        Enum.each(src, &IO.puts(&1))
      else
        {:error, reason, _file} ->
          Logger.error(reason)
          {:error, reason}
      end
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
            :ok

          {:error, reason} ->
            IO.puts(" Failed to save plugin data: #{reason}")
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts(" Failed to fetch plugin: #{reason}")
        {:error, reason}
    end
  end
end
