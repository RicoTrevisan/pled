defmodule Pled.Commands.Upload do
  @moduledoc """
  Command for uploading files to Bubble.io CDN.
  """

  def run(file_path) do
    plugin_file = "src/plugin.json"

    case File.exists?(plugin_file) do
      false ->
        {:error, "src/plugin.json not found"}

      true ->
        case File.exists?(file_path) do
          false ->
            IO.puts("Error: File '#{file_path}' does not exist")
            {:error, :file_not_found}

          true ->
            case Pled.BubbleApi.upload_file(file_path) do
              {:ok, cdn_url} ->
                IO.puts("File uploaded successfully!")
                IO.puts("CDN URL: #{cdn_url}")

                case add_asset_to_plugin(file_path, cdn_url) do
                  :ok ->
                    IO.puts("Asset added to plugin.json")
                    :ok

                  {:error, reason} ->
                    IO.puts("Warning: Failed to update plugin.json: #{reason}")
                    # Still consider upload successful
                    :ok
                end

              {:error, reason} ->
                IO.puts("Upload failed: #{reason}")
                {:error, reason}
            end
        end
    end

    IO.puts("Uploading file: #{file_path}")
  end

  defp add_asset_to_plugin(file_path, cdn_url) do
    plugin_file = "src/plugin.json"

    with {:ok, content} <- File.read(plugin_file),
         {:ok, plugin_data} <- Jason.decode(content) do
      filename = Path.basename(file_path)
      asset_key = generate_asset_key(plugin_data)

      asset_entry = %{
        "name" => filename,
        "url" => cdn_url
      }

      updated_assets = Map.put(plugin_data["assets"] || %{}, asset_key, asset_entry)
      updated_plugin = Map.put(plugin_data, "assets", updated_assets)

      case Jason.encode(updated_plugin, pretty: true) do
        {:ok, json_content} ->
          File.write(plugin_file, json_content)

        {:error, reason} ->
          {:error, "Failed to encode JSON: #{reason}"}
      end
    else
      {:error, reason} -> {:error, "Failed to process plugin.json: #{reason}"}
    end
  end

  defp generate_asset_key(plugin_data) do
    existing_keys = Map.keys(plugin_data["assets"] || %{})

    # Generate a 3-letter key that doesn't exist
    generate_unique_key(existing_keys)
  end

  defp generate_unique_key(existing_keys) do
    # Generate random 3-letter combinations until we find one that doesn't exist
    key = for _ <- 1..3, into: "", do: <<Enum.random(?A..?Z)>>

    if key in existing_keys do
      generate_unique_key(existing_keys)
    else
      key
    end
  end
end
