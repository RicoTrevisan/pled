defmodule Pled.Integration.ElementActionsTest do
  use ExUnit.Case, async: true
  alias Pled.Commands.{Decoder, Encoder}

  describe "element actions integration tests" do
    @describetag :tmp_dir
    @describetag :integration

    setup %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "src"))
      File.mkdir_p!(Path.join(tmp_dir, "dist"))
      {:ok, []}
    end

    test "element actions round-trip: decode then encode preserves structure", %{tmp_dir: tmp_dir} do
      # Original plugin data with element actions
      original_plugin = %{
        "assets" => %{},
        "dependencies" => %{
          "plugin_api_version" => "4",
          "use_jquery" => true
        },
        "editor_counter" => 100,
        "meta_data" => %{
          "name" => "Test Plugin"
        },
        "plugin_elements" => %{
          "ABC" => %{
            "display" => "Rich Text Editor",
            "category" => "input forms",
            "code" => %{
              "initialize" => %{
                "fn" => "function(instance, context) {\n  console.log('init');\n}"
              },
              "update" => %{
                "fn" => "function(instance, properties, context) {\n  console.log('update');\n}"
              },
              "preview" => %{
                "fn" => "function(instance, properties) {\n  console.log('preview');\n}"
              },
              "reset" => %{"fn" => "function(instance, context) {\n  console.log('reset');\n}"}
            },
            "actions" => %{
              "ACp" => %{
                "caption" => "Table toggle header row",
                "code" => %{
                  "fn" =>
                    "function(instance, properties, context) {\n  if (!instance.data.editor_is_ready)\n    return instance.data.returnAndReportErrorIfEditorNotReady(\n      \"table_-_toggle_header_row\"\n    );\n\n  instance.data.editor.chain().focus().toggleHeaderRow().run();\n}"
                }
              },
              "ACR" => %{
                "caption" => "Remove link",
                "code" => %{
                  "fn" =>
                    "function(instance, properties, context) {\n  if (!instance.data.editor_is_ready)\n    return instance.data.returnAndReportErrorIfEditorNotReady(\"Remove Link\");\n\n  if (instance.data.active_nodes.includes(\"Link\")) {\n    instance.data.editor.commands.unsetLink();\n  } else {\n    console.log(\"tried to add Link, but extension is not active.\");\n  }\n}"
                }
              },
              "NEW" => %{
                "caption" => "Custom Action",
                "type" => "element_action",
                "code" => %{
                  "fn" =>
                    "function(instance, properties, context) {\n  console.log('custom action executed');\n  instance.data.customMethod();\n}"
                }
              }
            },
            "default_dim" => %{
              "height" => 100,
              "width" => 600
            }
          }
        }
      }

      # Write original plugin.json
      src_plugin_path = Path.join([tmp_dir, "src", "plugin.json"])
      File.write!(src_plugin_path, Jason.encode!(original_plugin, pretty: true))

      # Step 1: Decode the plugin (creates local files)
      Decoder.decode(original_plugin, tmp_dir)

      # Verify files were created correctly
      element_dir = Path.join([tmp_dir, "src", "elements", "rich-text-editor-ABC"])
      actions_dir = Path.join(element_dir, "actions")

      assert File.exists?(element_dir)
      assert File.exists?(actions_dir)

      # Check that all action files were created
      expected_files = [
        "table-toggle-header-row-ACp.js",
        "table-toggle-header-row-ACp.key",
        "table-toggle-header-row-ACp.json",
        "remove-link-ACR.js",
        "remove-link-ACR.key",
        "remove-link-ACR.json",
        "custom-action-NEW.js",
        "custom-action-NEW.key",
        "custom-action-NEW.json"
      ]

      action_files = File.ls!(actions_dir)

      Enum.each(expected_files, fn file ->
        assert file in action_files, "Missing file: #{file}"
      end)

      # Verify key files contain correct keys
      assert File.read!(Path.join(actions_dir, "table-toggle-header-row-ACp.key")) == "ACp"
      assert File.read!(Path.join(actions_dir, "remove-link-ACR.key")) == "ACR"
      assert File.read!(Path.join(actions_dir, "custom-action-NEW.key")) == "NEW"

      # Verify JS files contain cleaned JavaScript (without function wrapper)
      table_js = File.read!(Path.join(actions_dir, "table-toggle-header-row-ACp.js"))

      assert String.contains?(
               table_js,
               "instance.data.editor.chain().focus().toggleHeaderRow().run();"
             )

      refute String.contains?(table_js, "function(instance, properties, context) {")

      # Verify metadata JSON files contain action data without the code.fn
      table_metadata =
        Path.join(actions_dir, "table-toggle-header-row-ACp.json")
        |> File.read!()
        |> Jason.decode!()

      assert table_metadata["caption"] == "Table toggle header row"
      assert Map.has_key?(table_metadata, "code")
      refute Map.has_key?(table_metadata["code"], "fn")

      # Step 2: Encode back to JSON
      opts = [
        src_dir: Path.join(tmp_dir, "src"),
        dist_dir: Path.join(tmp_dir, "dist"),
        elements_dir: Path.join([tmp_dir, "src", "elements"]),
        actions_dir: Path.join([tmp_dir, "src", "actions"])
      ]

      # Change to tmp_dir for encoding
      original_cwd = File.cwd!()
      File.cd!(tmp_dir)

      try do
        Encoder.encode()
      after
        File.cd!(original_cwd)
      end

      # Step 3: Verify the encoded JSON matches the original structure
      encoded_json =
        Path.join([tmp_dir, "dist", "plugin.json"])
        |> File.read!()
        |> Jason.decode!()

      # Check that element actions were properly reconstructed
      encoded_element = encoded_json["plugin_elements"]["ABC"]
      encoded_actions = encoded_element["actions"]

      assert Map.has_key?(encoded_actions, "ACp")
      assert Map.has_key?(encoded_actions, "ACR")
      assert Map.has_key?(encoded_actions, "NEW")

      # Verify action structure is correct
      table_action = encoded_actions["ACp"]
      assert table_action["caption"] == "Table toggle header row"
      assert Map.has_key?(table_action["code"], "fn")

      # Verify the function wrapper was re-added
      table_fn = table_action["code"]["fn"]
      assert String.starts_with?(table_fn, "function(instance, properties, context) {")
      assert String.ends_with?(table_fn, "}")

      assert String.contains?(
               table_fn,
               "instance.data.editor.chain().focus().toggleHeaderRow().run();"
             )

      # Check remove link action
      remove_action = encoded_actions["ACR"]
      assert remove_action["caption"] == "Remove link"
      remove_fn = remove_action["code"]["fn"]
      assert String.contains?(remove_fn, "instance.data.editor.commands.unsetLink();")

      # Check custom action
      custom_action = encoded_actions["NEW"]
      assert custom_action["caption"] == "Custom Action"
      assert custom_action["type"] == "element_action"
      custom_fn = custom_action["code"]["fn"]
      assert String.contains?(custom_fn, "instance.data.customMethod();")
    end

    test "handles missing metadata gracefully", %{tmp_dir: tmp_dir} do
      # Create element structure manually (simulating user editing files)
      element_dir = Path.join([tmp_dir, "src", "elements", "test-element-ABC"])
      actions_dir = Path.join(element_dir, "actions")
      File.mkdir_p!(actions_dir)

      # Create element metadata
      File.write!(Path.join(element_dir, ".key"), "ABC")

      element_metadata = %{
        "display" => "Test Element",
        "category" => "input forms",
        "code" => %{}
      }

      File.write!(
        Path.join(element_dir, "ABC.json"),
        Jason.encode!(element_metadata, pretty: true)
      )

      # Create required JS files
      ["initialize.js", "update.js", "preview.js", "reset.js"]
      |> Enum.each(fn file ->
        File.write!(Path.join(element_dir, file), "console.log('#{file}');")
      end)

      # Create action JS file without metadata (user added manually)
      File.write!(
        Path.join(actions_dir, "my-custom-action-XYZ.js"),
        "console.log('custom action');"
      )

      File.write!(Path.join(actions_dir, "my-custom-action-XYZ.key"), "XYZ")
      # Intentionally omit the .json metadata file

      # Create src plugin.json
      src_plugin = %{
        "meta_data" => %{"name" => "Test Plugin"},
        "dependencies" => %{"plugin_api_version" => "4"}
      }

      File.write!(
        Path.join([tmp_dir, "src", "plugin.json"]),
        Jason.encode!(src_plugin, pretty: true)
      )

      # Encode should handle missing metadata gracefully
      original_cwd = File.cwd!()
      File.cd!(tmp_dir)

      try do
        Encoder.encode()
      after
        File.cd!(original_cwd)
      end

      # Verify the encoded JSON includes the action with generated metadata
      encoded_json =
        Path.join([tmp_dir, "dist", "plugin.json"])
        |> File.read!()
        |> Jason.decode!()

      element = encoded_json["plugin_elements"]["ABC"]
      actions = element["actions"]

      assert Map.has_key?(actions, "XYZ")
      action = actions["XYZ"]

      # Should have generated caption from filename
      assert action["caption"] == "My Custom Action"
      assert Map.has_key?(action["code"], "fn")
      assert String.contains?(action["code"]["fn"], "console.log('custom action');")
    end
  end
end
