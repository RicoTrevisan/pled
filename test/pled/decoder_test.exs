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
      # keep track of the cwd
      cwd = File.cwd!()

      # jump into the tmp_dir to simulate a user using `pled pull`
      File.cd!(tmp_dir)

      plugin_data
      |> Decoder.decode_html_header()

      # go back to the cwd so that other tests can pass
      File.cd!(cwd)

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
      tmp_dir |> File.cd!()

      Decoder.decode(plugin_data)

      dir = Path.join(tmp_dir, "/src/elements/tiptap/actions")

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
end
