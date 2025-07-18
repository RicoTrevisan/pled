defmodule Pled.DecoderTest do
  use ExUnit.Case, async: true

  alias Pled.Commands.Decoder

  describe "decoder" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      plugin_data = File.read!("priv/examples/small_plugin.json") |> Jason.decode!()
      src_dir = Path.join(tmp_dir, "src")
      File.mkdir(src_dir)

      {:ok, plugin_data: plugin_data}
    end

    test "html_header", %{plugin_data: plugin_data, tmp_dir: tmp_dir} do
      plugin_data
      |> Decoder.decode_html_header(tmp_dir)

      ls =
        tmp_dir
        |> Path.join("src")
        |> File.ls!()

      assert "shared.html" in ls

      html_file = Path.join(tmp_dir, "src/shared.html")
      assert File.exists?(html_file)

      snippet = File.read!(html_file)
      assert snippet =~ "script"
    end

    test "remove_bubbleism/1", %{tmp_dir: tmp_dir, plugin_data: plugin_data} do
      Decoder.decode(plugin_data, tmp_dir)

      dir = Path.join(tmp_dir, "/src/elements/tiptap-AAC/actions")

      File.ls!(dir)
      |> Enum.each(fn file ->
        Path.join(dir, file) |> File.read!()
      end)

      string =
        """
        function(instance, properties, context) {

          //Load any data
          //Do the operation

        }
        """

      refute Decoder.remove_bubbleisms(string) =~ "function"
    end
  end

  describe "key-slug combination functionality" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      src_dir = Path.join(tmp_dir, "src")
      File.mkdir(src_dir)
      {:ok, []}
    end

    test "elements with same display name get unique directories", %{tmp_dir: tmp_dir} do
      plugin_data = %{
        "plugin_elements" => %{
          "key1" => %{"display" => "Same Name", "code" => %{}},
          "key2" => %{"display" => "Same Name", "code" => %{}}
        }
      }

      Decoder.decode_elements(plugin_data, tmp_dir)

      elements_dir = Path.join(tmp_dir, "src/elements")
      dirs = File.ls!(elements_dir)

      assert "same-name-key1" in dirs
      assert "same-name-key2" in dirs
      assert length(dirs) == 2
    end

    test "actions with same display name get unique directories", %{tmp_dir: tmp_dir} do
      plugin_data = %{
        "plugin_actions" => %{
          "key1" => %{"display" => "Same Action", "code" => %{}},
          "key2" => %{"display" => "Same Action", "code" => %{}}
        }
      }

      Decoder.decode_actions(plugin_data, tmp_dir)

      actions_dir = Path.join(tmp_dir, "src/actions")
      dirs = File.ls!(actions_dir)

      assert "same-action-key1" in dirs
      assert "same-action-key2" in dirs
      assert length(dirs) == 2
    end

    test "element actions with same caption get unique filenames", %{tmp_dir: tmp_dir} do
      plugin_data = %{
        "plugin_elements" => %{
          "element_key" => %{
            "display" => "Test Element",
            "code" => %{},
            "actions" => %{
              "action_key1" => %{
                "caption" => "Same Action",
                "code" => %{"fn" => "console.log('1');"}
              },
              "action_key2" => %{
                "caption" => "Same Action",
                "code" => %{"fn" => "console.log('2');"}
              }
            }
          }
        }
      }

      Decoder.decode_elements(plugin_data, tmp_dir)

      actions_dir = Path.join(tmp_dir, "src/elements/test-element-element_key/actions")
      files = File.ls!(actions_dir)

      assert "same-action-action_key1.js" in files
      assert "same-action-action_key2.js" in files
      assert length(files) == 2
    end
  end
end
