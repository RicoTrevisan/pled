defmodule Pled.EncoderTest do
  use ExUnit.Case, async: true

  alias Pled.Commands.Encoder

  describe "encode actions" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      original_cwd = File.cwd!()

      plugin_data =
        File.read!(Path.join([original_cwd, "priv/examples/small_plugin.json"]))
        |> Jason.decode!()

      Pled.Commands.Decoder.decode(plugin_data, tmp_dir)

      src_dir = "src"
      dist_dir = "dist"
      File.mkdir_p(dist_dir)

      opts = [
        src_dir: src_dir,
        dist_dir: dist_dir,
        elements_dir: Path.join(src_dir, "elements"),
        actions_dir: Path.join(src_dir, "actions")
      ]

      {:ok, src_json: plugin_data, opts: opts}
    end
  end

  describe "encode elements" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      original_cwd = File.cwd!()

      File.cp(
        Path.join([original_cwd, "priv/examples/single_element.json"]),
        Path.join(tmp_dir, "AAC.json")
      )

      File.write(Path.join(tmp_dir, ".key"), "AAC")

      File.write(tmp_dir |> Path.join("initialize.js"), "console.log('this is a test')")
      File.write(tmp_dir |> Path.join("update.js"), "console.log('this is a test')")
      File.write(tmp_dir |> Path.join("reset.js"), "console.log('this is a test')")
      File.write(tmp_dir |> Path.join("preview.js"), "console.log('this is a test')")

      {:ok, %{}}
    end

    test "encode_element/1", %{tmp_dir: tmp_dir} do
      encoded_element = Encoder.Element.encode_element(tmp_dir)
      assert is_tuple(encoded_element)
      {:ok, {key, value}} = encoded_element
      assert key == "AAC"
      assert is_map(value["code"])
      assert Map.keys(value["code"]["initialize"])
    end

    test "generate_code_block/1", %{tmp_dir: tmp_dir} do
      generated_code = Encoder.Element.generate_code_block(tmp_dir)
      assert is_map(generated_code)
      assert Map.keys(generated_code) == ["code"]
      assert Map.keys(generated_code["code"]) == ["initialize", "preview", "reset", "update"]
    end

    test "generate_js_file/2 :initialize", %{tmp_dir: tmp_dir} do
      generated_map = Encoder.Element.generate_js_file(:initialize, tmp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["initialize"]
      assert Map.keys(generated_map["initialize"]) == ["fn"]

      generated_fn = generated_map["initialize"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, context) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "generate_js_file/2 :update", %{tmp_dir: tmp_dir} do
      generated_map = Encoder.Element.generate_js_file(:update, tmp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["update"]
      assert Map.keys(generated_map["update"]) == ["fn"]

      generated_fn = generated_map["update"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, properties, context) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "generate_js_file/2 :reset", %{tmp_dir: tmp_dir} do
      generated_map = Encoder.Element.generate_js_file(:reset, tmp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["reset"]
      assert Map.keys(generated_map["reset"]) == ["fn"]

      generated_fn = generated_map["reset"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, context) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "generate_js_file/2 :preview", %{tmp_dir: tmp_dir} do
      generated_map = Encoder.Element.generate_js_file(:preview, tmp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["preview"]
      assert Map.keys(generated_map["preview"]) == ["fn"]

      generated_fn = generated_map["preview"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, properties) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "field reordering with rank changes only", %{tmp_dir: tmp_dir} do
      # Create a fields.txt with reordered fields (no caption changes)
      fields_content = """
      Header font color (ADe)
      Allowed MIME Types (AFz)
      """
      File.write!(Path.join(tmp_dir, "fields.txt"), fields_content)

      {:ok, {_key, result}} = Encoder.Element.encode_element(tmp_dir)
      
      fields = result["fields"]
      assert fields["ADe"]["rank"] == 0  # Was 56, now should be 0
      assert fields["AFz"]["rank"] == 1  # Was 101, now should be 1
      
      # Captions should remain unchanged
      assert fields["ADe"]["caption"] == "Header font color"
      assert fields["AFz"]["caption"] == "Allowed MIME Types"
    end

    test "field reordering with caption changes", %{tmp_dir: tmp_dir} do
      # Mock IO.gets to automatically confirm changes
      import ExUnit.CaptureIO
      
      fields_content = """
      Modified Header Color (ADe)
      Custom MIME Types (AFz)
      """
      File.write!(Path.join(tmp_dir, "fields.txt"), fields_content)

      # Capture the output and provide 'y' as input to confirm changes
      result = capture_io([input: "y\n"], fn ->
        {:ok, {_key, encoded}} = Encoder.Element.encode_element(tmp_dir)
        send(self(), {:result, encoded})
      end)
      
      assert_received {:result, encoded}
      
      fields = encoded["fields"]
      assert fields["ADe"]["caption"] == "Modified Header Color"
      assert fields["AFz"]["caption"] == "Custom MIME Types"
      assert fields["ADe"]["rank"] == 0
      assert fields["AFz"]["rank"] == 1
      
      # Should show change detection
      assert result =~ "Field changes detected"
      assert result =~ "Caption changes"
    end

    test "field validation - duplicate keys", %{tmp_dir: tmp_dir} do
      fields_content = """
      Header font color (ADe)
      Duplicate field (ADe)
      """
      File.write!(Path.join(tmp_dir, "fields.txt"), fields_content)

      assert {:error, error_msg} = Encoder.Element.encode_element(tmp_dir)
      assert error_msg =~ "Duplicate keys found"
      assert error_msg =~ "ADe (appears 2 times)"
    end

    test "field validation - malformed lines", %{tmp_dir: tmp_dir} do
      fields_content = """
      Header font color (ADe)
      This line is malformed
      """
      File.write!(Path.join(tmp_dir, "fields.txt"), fields_content)

      assert {:error, error_msg} = Encoder.Element.encode_element(tmp_dir)
      assert error_msg =~ "Field parsing failed"
      assert error_msg =~ "Malformed line: This line is malformed"
    end
  end

  describe "encode root" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      original_cwd = File.cwd!()

      plugin_data =
        File.read!(Path.join([original_cwd, "priv/examples/plugin.json"])) |> Jason.decode!()

      Pled.Commands.Decoder.decode(plugin_data, tmp_dir)

      src_dir = "src"
      dist_dir = "dist"
      File.mkdir_p(dist_dir)

      opts = [
        src_dir: src_dir,
        dist_dir: dist_dir,
        elements_dir: Path.join(src_dir, "elements"),
        actions_dir: Path.join(src_dir, "actions")
      ]

      {:ok, src_json: plugin_data, opts: opts}
    end

    test "html snippet", %{src_json: src_json, opts: opts} do
      updated_json = Encoder.encode_html(src_json, opts)

      assert Map.has_key?(updated_json, "html_header")
      assert Map.has_key?(updated_json["html_header"], "snippet")
      assert get_in(updated_json, ["html_header", "snippet"]) =~ "script"
    end
  end
end
