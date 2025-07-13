defmodule Pled.DecoderTest do
  use ExUnit.Case, async: true

  alias Pled.Commands.Encoder

  describe "encode/1" do
    setup do
      temp_dir = System.tmp_dir!()
      {:ok, %{temp_dir: temp_dir}}
    end

    test "generate_js_file/2 :initialize", %{temp_dir: temp_dir} do
      File.write(temp_dir |> Path.join("initialize.js"), "console.log('this is a test')")
      generated_map = Encoder.generate_js_file(:initialize, temp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["initialize"]
      assert Map.keys(generated_map["initialize"]) == ["fn"]

      generated_fn = generated_map["initialize"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, context) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "generate_js_file/2 :update", %{temp_dir: temp_dir} do
      File.write(temp_dir |> Path.join("update.js"), "console.log('this is a test')")
      generated_map = Encoder.generate_js_file(:update, temp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["update"]
      assert Map.keys(generated_map["update"]) == ["fn"]

      generated_fn = generated_map["update"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, properties, context) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "generate_js_file/2 :reset", %{temp_dir: temp_dir} do
      File.write(temp_dir |> Path.join("reset.js"), "console.log('this is a test')")
      generated_map = Encoder.generate_js_file(:reset, temp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["reset"]
      assert Map.keys(generated_map["reset"]) == ["fn"]

      generated_fn = generated_map["reset"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, context) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "generate_js_file/2 :preview", %{temp_dir: temp_dir} do
      File.write(temp_dir |> Path.join("preview.js"), "console.log('this is a test')")
      generated_map = Encoder.generate_js_file(:preview, temp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["preview"]
      assert Map.keys(generated_map["preview"]) == ["fn"]

      generated_fn = generated_map["preview"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, properties) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end
  end
end
