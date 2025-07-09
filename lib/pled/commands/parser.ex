defmodule Pled.Commands.Parser do
  def parse(plugin_data) do
    parse_elements(plugin_data)
    :ok
  end

  def parse_elements(plugin_data) do
    plugin_data
    |> Map.get("plugin_elements", [])
    |> Enum.map(fn {_key, element} ->
      name = Map.get(element, "display") |> String.downcase()

      element_dir = Path.join("src", name)

      File.mkdir_p!(element_dir)

      initialize_content = element["code"]["initialize"]["fn"]

      element_dir
      |> Path.join("initialize.js")
      |> File.write(initialize_content)

      :ok
    end)
  end
end
