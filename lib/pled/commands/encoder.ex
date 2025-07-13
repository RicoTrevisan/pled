defmodule Pled.Commands.Encoder do
  @moduledoc """
  Module that turns the local files into Bubble-accepted json
  """
  alias Pled.Commands.Encoder.Element

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

    output_json =
      src_json
      |> Element.encode_elements(opts)

    dist_dir
    |> Path.join("plugin.json")
    |> File.write(output_json |> Jason.encode!(pretty: true))

    # encode_actions()
  end
end
