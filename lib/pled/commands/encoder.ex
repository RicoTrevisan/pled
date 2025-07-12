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
      dist_dir: dist_dir,
      elements_dir: Path.join(src_dir, "elements"),
      actions_dir: Path.join(src_dir, "actions")
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
    elements_dir =
      opts
      |> Keyword.get(:elements_dir)

    elements =
      elements_dir
      |> File.ls!()
      |> Enum.reduce(
        %{},
        fn element_dir, acc ->
          {key, json} =
            encode_element(Path.join(elements_dir, element_dir))

          Map.put(acc, key, json)
        end
      )

    Map.put(src_json, "elements", elements)
  end

  defp encode_element(element_dir) do
    IO.puts("encoding element #{element_dir}")

    key =
      element_dir
      |> Path.join(".key")
      |> File.read!()

    code =
      ["initialize", "preview", "reset", "update"]
      |> Enum.reduce(
        %{},
        fn item, acc ->
          IO.puts("encoding #{item}.js")

          content =
            element_dir
            |> Path.join("#{item}.js")
            |> File.read!()

          content =
            if item == "update" do
              "function(instance, properties, context) {\n" <> content <> "\n}"
            else
              "function(instance, context) {\n" <> content <> "\n}"
            end

          Map.put(acc, item, %{"fn" => content})
        end
      )

    json =
      element_dir
      |> Path.join("#{key}.json")
      |> File.read!()
      |> Jason.decode!()

    json =
      Map.put(json, "code", code)

    {key, json}
  end
end
