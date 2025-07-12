defmodule Pled.Commands.Decoder do
  def decode(plugin_data) do
    decode_elements(plugin_data)
    decode_actions(plugin_data)
    :ok
  end

  def decode_actions(plugin_data) do
    actions_dir = Path.join("src", "actions")

    plugin_data
    |> Map.get("plugin_actions", [])
    |> Enum.map(&decode_action(&1, actions_dir))
  end

  defp decode_action({key, action_data}, actions_dir) do
    name =
      action_data
      |> Map.get("display")
      |> Slug.slugify()

    action_dir = Path.join(actions_dir, name)
    File.mkdir_p!(action_dir)

    # write the key name to the directory
    File.write("#{action_dir}/.key", key)
    File.write("#{action_dir}/#{key}.json", Jason.encode!(action_data, pretty: true))

    ["client", "server"]
    |> Enum.each(fn func ->
      content = get_in(action_data, ["code", func, "fn"])

      action_dir
      |> Path.join("#{func}.js")
      |> File.write(content)
    end)
  end

  #
  # ELEMENTS
  #
  def decode_elements(plugin_data) do
    elements_dir = Path.join("src", "elements")

    plugin_data
    |> Map.get("plugin_elements", [])
    |> Enum.map(&decode_element(&1, elements_dir))
  end

  defp decode_element({key, element_data}, elements_dir) do
    name = Map.get(element_data, "display") |> Slug.slugify()

    element_dir = Path.join(elements_dir, name)

    File.mkdir_p!(element_dir)

    # write the key name to the directory
    File.write("#{element_dir}/.key", key)
    File.write("#{element_dir}/#{key}.json", Jason.encode!(element_data, pretty: true))

    ["initialize", "preview", "reset", "update"]
    |> Enum.each(fn func ->
      content = get_in(element_data, ["code", func, "fn"])

      element_dir
      |> Path.join("#{func}.js")
      |> File.write(content)

      decode_element_actions(element_data, element_dir)
    end)

    :ok
  end

  defp decode_element_actions(element_data, element_dir) do
    actions_dir = Path.join([element_dir, "actions"])
    File.mkdir_p!(actions_dir)

    element_data
    |> Map.get("actions")
    |> Enum.each(fn {_key, action_data} ->
      name = action_data["caption"] |> Slug.slugify()
      content = get_in(action_data, ["code", "fn"])

      actions_dir
      |> Path.join("#{name}.js")
      |> File.write(content)
    end)
  end
end
