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
    json = update_element_actions_js(json, element_dir)

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

  def update_element_actions_js(json, element_dir) do
    actions_dir = Path.join(element_dir, "actions")

    if File.exists?(actions_dir) and Map.has_key?(json, "actions") do
      IO.puts("updating element actions from #{actions_dir}")

      # Get existing actions from JSON
      existing_actions = json["actions"]

      # Update actions with JS content from files
      updated_actions =
        actions_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".js"))
        |> Enum.reduce(existing_actions, fn js_file, acc ->
          update_action_with_js_file(js_file, actions_dir, acc)
        end)

      Map.put(json, "actions", updated_actions)
    else
      json
    end
  end

  defp update_action_with_js_file(js_file, actions_dir, actions) do
    try do
      # Extract key from filename (last part after last dash)
      key =
        js_file
        |> String.replace_suffix(".js", "")
        |> String.split("-")
        |> List.last()

      # Read the JavaScript content
      js_path = Path.join(actions_dir, js_file)
      js_content = File.read!(js_path)

      # Update the action's JavaScript code if the action exists
      if Map.has_key?(actions, key) do
        updated_action =
          actions[key]
          |> put_in(["code", "fn"], "function(instance, properties, context) {\n" <> js_content <> "\n}")

        Map.put(actions, key, updated_action)
      else
        IO.puts("Warning: Action with key '#{key}' not found in element JSON, skipping #{js_file}")
        actions
      end
    rescue
      e ->
        IO.puts("Error updating action from #{js_file}: #{inspect(e)}")
        IO.puts("Skipping this action...")
        actions
    end
  end

end
