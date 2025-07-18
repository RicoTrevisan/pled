defmodule Pled.Commands.Decoder do
  def decode(plugin_data, base_dir \\ File.cwd!()) do
    decode_elements(plugin_data, base_dir)
    decode_actions(plugin_data, base_dir)
    decode_html_header(plugin_data, base_dir)
    :ok
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

    # write the key name to the directory
    File.write("#{action_dir}/.key", key)
    File.write("#{action_dir}/#{key}.json", Jason.encode!(action_data, pretty: true))

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
    File.write("#{element_dir}/.key", key)
    File.write("#{element_dir}/#{key}.json", Jason.encode!(element_data, pretty: true))

    decode_element_html_header(element_data, element_dir)

    ["initialize", "preview", "reset", "update"]
    |> Enum.each(fn func ->
      content =
        element_data
        |> get_in(["code", func, "fn"])
        |> remove_bubbleisms()

      element_dir
      |> Path.join("#{func}.js")
      |> File.write(content)

      decode_element_actions(element_data, element_dir)
      :ok
    end)

    :ok
  end

  defp decode_element_actions(element_data, element_dir) do
    actions_dir = Path.join([element_dir, "actions"])
    File.mkdir_p!(actions_dir)

    actions = element_data |> Map.get("actions")

    if actions do
      actions
      |> Enum.each(fn {key, action_data} ->
        name = action_data["caption"] |> Slug.slugify()

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
  end
end
