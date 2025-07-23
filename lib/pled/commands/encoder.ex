defmodule Pled.Commands.Encoder do
  @moduledoc """
  Module that turns the local files into Bubble-accepted json
  """
  alias Pled.Commands.Encoder.Element
  alias Pled.Commands.Encoder.Action

  def encode do
    dist_dir = "dist"
    File.mkdir_p(dist_dir)

    src_dir = "src"

    src_json =
      src_dir
      |> Path.join("plugin.json")
      |> File.read!()
      |> Jason.decode!()

    opts = [
      src_dir: src_dir,
      dist_dir: dist_dir,
      elements_dir: Path.join(src_dir, "elements"),
      actions_dir: Path.join(src_dir, "actions")
    ]

    case Element.encode_elements(src_json, opts) do
      {:ok, json_with_elements} ->
        output_json =
          json_with_elements
          |> Action.encode_actions(opts)
          |> encode_html(opts)

        IO.puts("generated output json, writing it to dist/plugin.json")

        dist_dir
        |> Path.join("plugin.json")
        |> File.write(output_json |> Jason.encode!(pretty: true))

        IO.puts("dist/plugin.json generated")
        :ok
        
      {:error, reason} ->
        IO.puts("\n❌ Encoding failed: #{reason}")
        IO.puts("Please fix the issues and try again.")
        {:error, reason}
    end
  end

  def encode_html(json, opts \\ []) do
    IO.puts("reading shared html...")
    src_dir = Keyword.get(opts, :src_dir)
    html_path = Path.join(src_dir, "shared.html")

    if File.exists?(html_path) do
      snippet = File.read!(html_path)
      Map.merge(json, %{"html_header" => %{"snippet" => snippet}})
    else
      json
    end
  end
end
