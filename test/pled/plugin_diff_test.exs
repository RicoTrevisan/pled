defmodule Pled.PluginDiffTest do
  use ExUnit.Case, async: true

  alias Pled.PluginDiff

  describe "diff/2" do
    test "reports metadata field drift" do
      a = base_plugin()
      b = put_in(a, ["description"], "Updated")

      diff = PluginDiff.diff(a, b)

      assert PluginDiff.changed?(diff)
      assert diff.summary[:metadata_field_changed] == 1

      assert Enum.any?(diff.changes, fn change ->
               change.path == ["metadata", "description"] and change.before == "Base" and
                 change.after == "Updated"
             end)
    end

    test "captures element additions" do
      a = base_plugin()
      b = put_in(a, ["plugin_elements", "beta"], sample_element("Beta"))

      diff = PluginDiff.diff(a, b)

      assert diff.summary[:element_added] == 1

      assert Enum.any?(diff.changes, fn change ->
               change.type == :element_added and change.path == ["elements", "beta"]
             end)
    end

    test "emits deep paths for code edits" do
      a = base_plugin()

      b =
        put_in(
          a,
          ["plugin_elements", "alpha", "code", "initialize", "fn"],
          "function(instance) { return 42; }"
        )

      diff = PluginDiff.diff(a, b)

      assert Enum.any?(diff.changes, fn change ->
               change.type == :element_field_changed and
                 change.path == [
                   "elements",
                   "alpha",
                   "data",
                   "code",
                   "initialize",
                   "fn",
                   "raw"
                 ] and
                 change.before == "function(instance) { return instance; }" and
                 change.after == "function(instance) { return 42; }"
             end)
    end
  end

  defp base_plugin do
    %{
      "name" => "Sample",
      "description" => "Base",
      "plugin_elements" => %{"alpha" => sample_element("Alpha")},
      "plugin_actions" => %{"run" => sample_action("Run")}
    }
  end

  defp sample_element(display) do
    %{
      "display" => display,
      "code" => %{
        "initialize" => %{"fn" => "function(instance) { return instance; }"}
      }
    }
  end

  defp sample_action(display) do
    %{
      "display" => display,
      "code" => %{"fn" => "function(properties) { return properties; }"}
    }
  end
end
