defmodule Pled.Commands.Encoder.Element do
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

    Map.put(src_json, "plugin_elements", elements)
  end

  def encode_element(element_dir) do
    IO.puts("encoding element #{element_dir}")

    key =
      element_dir
      |> Path.join(".key")
      |> File.read!()

    json =
      element_dir
      |> Path.join("#{key}.json")
      |> File.read!()
      |> Jason.decode!()

    code_block = generate_code_block(element_dir)
    json = Map.merge(json, code_block)

    {key, json}
  end

  def generate_code_block(element_dir) do
    generated_functions =
      [:initialize, :preview, :reset, :update]
      |> Enum.map(fn type ->
        generate_js_file(type, element_dir)
      end)
      |> Enum.reduce(%{}, fn map, acc ->
        Map.merge(acc, map)
      end)

    %{"code" => generated_functions}
  end

  def generate_js_file(:initialize, element_dir) do
    content = File.read!(element_dir |> Path.join("initialize.js"))

    %{
      "initialize" => %{
        "fn" => "function(instance, context) {\n" <> content <> "\n}"
      }
    }
  end

  def generate_js_file(:update, element_dir) do
    content = File.read!(element_dir |> Path.join("update.js"))

    %{
      "update" => %{
        "fn" => "function(instance, properties, context) {\n" <> content <> "\n}"
      }
    }
  end

  def generate_js_file(:preview, element_dir) do
    content = File.read!(element_dir |> Path.join("preview.js"))

    %{
      "preview" => %{
        "fn" => "function(instance, properties) {\n" <> content <> "\n}"
      }
    }
  end

  def generate_js_file(:reset, element_dir) do
    content = File.read!(element_dir |> Path.join("reset.js"))

    %{
      "reset" => %{
        "fn" => "function(instance, context) {\n" <> content <> "\n}"
      }
    }
  end
end
