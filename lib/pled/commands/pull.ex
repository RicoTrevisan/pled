defmodule Pled.Commands.Pull do
  alias Pled.Commands.Decoder
  alias Pled.RemoteChecker
  alias Pled.UI

  def run(opts) do
    verbose? = Keyword.get(opts, :verbose, false)
    IO.puts("pulling")

    UI.info("Fetching plugin from Bubble.io...", verbose?)

    wipe? = Keyword.get(opts, :wipe, false)

    if wipe? do
      UI.info("Wiping src and dist directories...", verbose?)

      with {:ok, dist} <- File.rm_rf("dist"),
           {:ok, src} <- File.rm_rf("src") do
        UI.info("removed:", verbose?)
        Enum.each(dist, &UI.info(&1, verbose?))
        Enum.each(src, &UI.info(&1, verbose?))
      else
        {:error, reason, _file} ->
          IO.puts("Pull failed: #{inspect(reason)}")
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
            # Save remote snapshot for change detection
            case RemoteChecker.save_remote_snapshot(plugin_data) do
              :ok ->
                UI.info("Remote snapshot saved", verbose?)

              {:error, reason} ->
                UI.info("Warning: Failed to save remote snapshot: #{reason}", verbose?)
            end

            Decoder.decode(plugin_data, File.cwd!())
            UI.info("Plugin data saved to #{plugin_file}", verbose?)
            IO.puts("Pull completed")
            :ok

          {:error, reason} ->
            IO.puts("Pull failed: #{reason}")
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts("Pull failed: #{reason}")
        {:error, reason}
    end
  end
end
