defmodule Pled.EncoderTest do
  use ExUnit.Case, async: true

  alias Pled.Commands.Encoder

  describe "encode functions" do
    setup do
      temp_dir = System.tmp_dir!() |> Path.join("pled_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(temp_dir)

      File.cp("priv/examples/single_element.json", Path.join(temp_dir, "AAC.json"))
      File.write(Path.join(temp_dir, ".key"), "AAC")

      File.write(temp_dir |> Path.join("initialize.js"), "console.log('this is a test')")
      File.write(temp_dir |> Path.join("update.js"), "console.log('this is a test')")
      File.write(temp_dir |> Path.join("reset.js"), "console.log('this is a test')")
      File.write(temp_dir |> Path.join("preview.js"), "console.log('this is a test')")

      on_exit(fn ->
        # Clean up the entire temporary directory
        if File.exists?(temp_dir) do
          File.rm_rf!(temp_dir)
        end
      end)

      {:ok, %{temp_dir: temp_dir}}
    end

    test "encode_element/1", %{temp_dir: temp_dir} do
      encoded_element = Encoder.Element.encode_element(temp_dir)
      assert is_tuple(encoded_element)
      {key, value} = encoded_element
      assert key == "AAC"
      assert is_map(value["code"])
      assert Map.keys(value["code"]["initialize"])
    end

    test "generate_code_block/1", %{temp_dir: temp_dir} do
      generated_code = Encoder.Element.generate_code_block(temp_dir)
      assert is_map(generated_code)
      assert Map.keys(generated_code) == ["code"]
      assert Map.keys(generated_code["code"]) == ["initialize", "preview", "reset", "update"]
    end

    test "generate_js_file/2 :initialize", %{temp_dir: temp_dir} do
      generated_map = Encoder.Element.generate_js_file(:initialize, temp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["initialize"]
      assert Map.keys(generated_map["initialize"]) == ["fn"]

      generated_fn = generated_map["initialize"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, context) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "generate_js_file/2 :update", %{temp_dir: temp_dir} do
      generated_map = Encoder.Element.generate_js_file(:update, temp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["update"]
      assert Map.keys(generated_map["update"]) == ["fn"]

      generated_fn = generated_map["update"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, properties, context) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "generate_js_file/2 :reset", %{temp_dir: temp_dir} do
      generated_map = Encoder.Element.generate_js_file(:reset, temp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["reset"]
      assert Map.keys(generated_map["reset"]) == ["fn"]

      generated_fn = generated_map["reset"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, context) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end

    test "generate_js_file/2 :preview", %{temp_dir: temp_dir} do
      generated_map = Encoder.Element.generate_js_file(:preview, temp_dir)
      assert is_map(generated_map)
      assert Map.keys(generated_map) == ["preview"]
      assert Map.keys(generated_map["preview"]) == ["fn"]

      generated_fn = generated_map["preview"]["fn"]
      assert String.starts_with?(generated_fn, "function(instance, properties) {\n")
      assert String.ends_with?(generated_fn, "\n}")
    end
  end
end
