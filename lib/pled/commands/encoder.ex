defmodule Pled.Commands.Encoder do
  @moduledoc """
  Module that turns the local files into Bubble-accepted json
  """

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
      dist_dir: dist_dir
    ]

    output_json =
      src_json
      |> encode_elements(opts)

    dist_dir
    |> Path.join("plugin.json")
    |> File.write(output_json |> Jason.encode!(pretty: true))

    # encode_actions()
  end

  def encode_elements(%{} = src_json, opts) do
    src_dir = Keyword.get(opts, :src_dir)
    # for each
    src_dir
    |> Path.join("elements")
    |> File.ls!()
    |> Enum.each(&encode_element(&1, opts))

    src_json
  end

  defp encode_element(element_dir, opts) do
    src_json = Keyword.get(opts, :src_json)
  end
end
