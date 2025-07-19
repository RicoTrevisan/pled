defmodule Pled.EncoderTest do
  use ExUnit.Case, async: true

  alias Pled.Commands.Encoder

  describe "encode actions" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      original_cwd = File.cwd!()
      plugin_data = File.read!(Path.join([original_cwd, "priv/examples/small_plugin.json"])) |> Jason.decode!()
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

    test "dbg", %{src_json: src_json, opts: opts} do
      updated_json = Encoder.Action.encode_actions(src_json, opts)
      # dbg(updated_json)
    end
  end

  describe "encode elements" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      original_cwd = File.cwd!()
      File.cp(Path.join([original_cwd, "priv/examples/single_element.json"]), Path.join(tmp_dir, "AAC.json"))
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
      {key, value} = encoded_element
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
  end

  describe "encode root" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      original_cwd = File.cwd!()
      plugin_data = File.read!(Path.join([original_cwd, "priv/examples/plugin.json"])) |> Jason.decode!()
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
