defmodule Pled.Commands.Encoder.Element do
  def encode_elements(%{} = src_json, opts) do
    IO.puts("checking if plugin has elements...")

    elements_dir =
      opts
      |> Keyword.get(:elements_dir)

    if File.exists?(elements_dir) do
      IO.puts("encoding elements...")

      found_elements =
        elements_dir
        |> File.ls!()

      IO.puts("found elements: #{Enum.map(found_elements, &(&1 <> ", "))}")

      elements =
        Enum.reduce(
          found_elements,
          %{},
          fn element_dir, acc ->
            {key, json} =
              encode_element(Path.join(elements_dir, element_dir))

            Map.put(acc, key, json)
          end
        )

      Map.merge(src_json, %{"plugin_elements" => elements})
    else
      IO.puts("no elements found")
      src_json
    end
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

    json = generate_html_headers(json, element_dir)

    {key, json}
  end

  def generate_html_headers(json, element_dir) do
    html_path = Path.join(element_dir, "headers.html")

    if File.exists?(html_path) do
      snippet = File.read!(html_path)
      Map.merge(json, %{"headers" => %{"snippet" => snippet}})
    else
      json
    end
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
