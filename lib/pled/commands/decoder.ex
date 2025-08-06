defmodule Pled.Commands.Decoder do
  def decode(plugin_data, base_dir \\ File.cwd!()) do
    # Preserve original plugin data for field restoration
    preserve_original_plugin_data(plugin_data, base_dir)

    decode_elements(plugin_data, base_dir)
    decode_actions(plugin_data, base_dir)
    decode_html_header(plugin_data, base_dir)
    clean_plugin_data(base_dir)
    :ok
  end

  def clean_plugin_data(base_dir) do
    keys_to_drop = ["html_header", "plugin_actions", "plugin_elements"]

    plugin_path = Path.join([base_dir, "src", "plugin.json"])

    updated_json =
      plugin_path
      |> File.read!()
      |> Jason.decode!()
      |> Map.drop(keys_to_drop)

    File.write!(plugin_path, Jason.encode!(updated_json, pretty: true))
  end

  def preserve_original_plugin_data(plugin_data, base_dir) do
    original_path = Path.join([base_dir, "src", "plugin.json"])
    File.write!(original_path, Jason.encode!(plugin_data, pretty: true))
  end

  def decode_html_header(plugin_data, base_dir) do
    case get_in(plugin_data, ["html_header", "snippet"]) do
      nil ->
        :ok

      snippet ->
        html_path = Path.join([base_dir, "src", "shared.html"])
        File.write(html_path, snippet)
    end
  end

  def decode_actions(plugin_data, base_dir) do
    actions_dir = Path.join([base_dir, "src", "actions"])

    plugin_data
    |> Map.get("plugin_actions", [])
    |> Enum.map(&decode_action(&1, actions_dir))
  end

  defp decode_action({key, action_data}, actions_dir) do
    name =
      action_data
      |> Map.get("display")
      |> Slug.slugify()

    action_dir = Path.join(actions_dir, "#{name}-#{key}")
    File.mkdir_p!(action_dir)

    ["client", "server"]
    |> Enum.each(fn func ->
      content =
        action_data
        |> get_in(["code", func, "fn"])
        |> remove_bubbleisms()

      action_dir
      |> Path.join("#{func}.js")
      |> File.write(content)
    end)

    clean_action_data(name, action_data, action_dir)
  end

  def clean_action_data(name, action_data, action_dir) do
    file_path = Path.join(action_dir, "#{name}.json")
    code_data = Map.drop(action_data["code"], ["server", "client"])

    updated_action_data =
      Map.put(action_data, "code", code_data)

    File.write(file_path, Jason.encode!(updated_action_data, pretty: true))
  end

  #
  # ELEMENTS
  #
  def decode_elements(plugin_data, base_dir) do
    elements_dir = Path.join([base_dir, "src", "elements"])

    plugin_data
    |> Map.get("plugin_elements", [])
    |> Enum.map(&decode_element(&1, elements_dir))
  end

  defp decode_element({key, element_data}, elements_dir) do
    name = Map.get(element_data, "display") |> Slug.slugify()

    element_dir = Path.join(elements_dir, "#{name}-#{key}")

    File.mkdir_p!(element_dir)

    # write the key name to the directory
    # File.write("#{element_dir}/.key", key)

    decode_element_html_header(element_data, element_dir)
    decode_element_functions(element_data, element_dir)
    decode_element_actions_js(element_data, element_dir)
    decode_element_fields(element_data, element_dir)

    write_cleaned_element_data("#{element_dir}/#{key}.json", element_data)
  end

  def write_cleaned_element_data(path, element_data) do
    actions =
      case Map.get(element_data, "actions", nil) do
        nil ->
          %{}

        actions ->
          Enum.reduce(actions, %{}, fn {key, value}, acc ->
            updated_value = Map.drop(value, ["code"])

            Map.merge(acc, %{key => updated_value})
          end)
      end

    cleaned_element_data =
      element_data
      |> Map.drop(["code", "headers", "fields"])
      |> Map.put("actions", actions)

    File.write(path, Jason.encode!(cleaned_element_data, pretty: true))
  end

  def decode_element_fields(element_data, element_dir) do
    element_data
    |> Map.get("fields")
    |> case do
      nil ->
        :ok

      [] ->
        :ok

      fields ->
        simplified_fields =
          fields
          |> Enum.sort_by(fn {_key, fields} -> fields["rank"] end)
          |> Enum.map(fn {key, fields} ->
            fields["caption"] <> " (#{key})"
          end)
          |> Enum.join("\n")

        File.write!(
          Path.join([element_dir, "fields.txt"]),
          simplified_fields
        )
    end
  end

  def decode_element_functions(element_data, element_dir) do
    ["initialize", "preview", "reset", "update"]
    |> Enum.each(fn func ->
      content =
        element_data
        |> get_in(["code", func, "fn"])
        |> remove_bubbleisms()

      element_dir
      |> Path.join("#{func}.js")
      |> File.write(content)
    end)
  end

  defp decode_element_actions_js(element_data, element_dir) do
    actions_dir = Path.join(element_dir, "actions")
    actions = element_data |> Map.get("actions")

    if actions do
      File.mkdir_p!(actions_dir)

      actions
      |> Enum.each(fn {key, action_data} ->
        name = action_data["caption"] |> Slug.slugify()

        # Store only the JS content for easier editing
        content =
          action_data
          |> get_in(["code", "fn"])
          |> remove_bubbleisms()

        actions_dir
        |> Path.join("#{name}-#{key}.js")
        |> File.write(content)
      end)
    end
  end

  def decode_element_html_header(element_data, element_dir) do
    html =
      element_data
      |> get_in(["headers", "snippet"])

    html_path = Path.join(element_dir, "headers.html")
    File.write(html_path, html)
  end

  def remove_bubbleisms(nil), do: nil

  def remove_bubbleisms(string) do
    string
    |> String.replace(~r/(async )?function\([^)]+\) \{/, "")
    |> String.replace(~r/\}\n*$/, "")
    |> String.trim()
  end
end
