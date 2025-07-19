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
    json = encode_element_actions(json, element_dir)

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

  def encode_element_actions(json, element_dir) do
    actions_dir = Path.join(element_dir, "actions")

    if File.exists?(actions_dir) do
      IO.puts("encoding element actions from #{actions_dir}")

      actions =
        actions_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".js"))
        |> Enum.reduce(%{}, fn js_file, acc ->
          encode_single_action(js_file, actions_dir, acc)
        end)

      if map_size(actions) > 0 do
        Map.put(json, "actions", actions)
      else
        json
      end
    else
      json
    end
  end

  defp encode_single_action(js_file, actions_dir, acc) do
    try do
      # Try to get key from .key file first (most reliable)
      key_file = String.replace_suffix(js_file, ".js", ".key")
      key_path = Path.join(actions_dir, key_file)

      key =
        if File.exists?(key_path) do
          File.read!(key_path) |> String.trim()
        else
          # Fallback: extract key from filename
          js_file
          |> String.replace_suffix(".js", "")
          |> String.split("-")
          |> List.last()
        end

      # Read the JavaScript content
      js_path = Path.join(actions_dir, js_file)
      js_content = File.read!(js_path)

      # Try to read metadata, with fallback
      json_file = String.replace_suffix(js_file, ".js", ".json")
      json_path = Path.join(actions_dir, json_file)

      metadata =
        if File.exists?(json_path) do
          json_path
          |> File.read!()
          |> Jason.decode!()
        else
          # Fallback: create minimal metadata from filename
          caption =
            js_file
            |> String.replace_suffix(".js", "")
            |> String.split("-")
            # Remove the key part
            |> Enum.drop(-1)
            |> Enum.join("-")
            |> String.replace("-", " ")
            |> String.split()
            |> Enum.map(&String.capitalize/1)
            |> Enum.join(" ")

          IO.puts(
            "Warning: Missing metadata for #{js_file}, creating minimal action with caption '#{caption}'"
          )

          %{"caption" => caption}
        end

      # Reconstruct the action data
      action_data =
        metadata
        |> Map.put("code", %{
          "fn" => "function(instance, properties, context) {\n" <> js_content <> "\n}"
        })

      Map.put(acc, key, action_data)
    rescue
      e ->
        IO.puts("Error encoding action #{js_file}: #{inspect(e)}")
        IO.puts("Skipping this action...")
        acc
    end
  end
end
