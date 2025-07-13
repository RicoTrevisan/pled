defmodule Pled.FilesystemTest do
  use ExUnit.Case, async: true

  alias Pled.BubbleApi

  setup do
    # Create a temporary directory for each test
    temp_dir = System.tmp_dir!() |> Path.join("pled_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(temp_dir)

    src_dir = Path.join(temp_dir, "src")
    plugin_file = Path.join(src_dir, "plugin.json")

    env_file = Path.join(File.cwd!(), ".env.exs")

    if File.exists?(env_file) do
      Code.eval_file(env_file)
    end

    on_exit(fn ->
      # Clean up the entire temporary directory
      if File.exists?(temp_dir) do
        File.rm_rf!(temp_dir)
      end
    end)

    %{temp_dir: temp_dir, src_dir: src_dir, plugin_file: plugin_file}
  end

  @tag :integration
  test "fetches plugin data and saves to src/plugin.json", %{
    src_dir: src_dir,
    plugin_file: plugin_file
  } do
    # Create src directory
    File.mkdir_p!(src_dir)

    # Fetch plugin data from Bubble.io
    assert {:ok, plugin_data} = BubbleApi.fetch_plugin()

    # Ensure we got valid data
    assert is_map(plugin_data) or is_list(plugin_data)

    # Encode to JSON and write to file
    json_content = Jason.encode!(plugin_data, pretty: true)

    assert :ok = File.write(plugin_file, json_content)

    # Verify file was created
    assert File.exists?(plugin_file)

    # Verify file contains valid JSON
    assert {:ok, file_content} = File.read(plugin_file)
    assert {:ok, parsed_data} = Jason.decode(file_content)

    # Verify the data matches what we fetched
    assert parsed_data == plugin_data

    # Verify file size is reasonable (not empty)
    assert File.stat!(plugin_file).size > 0
  end

  @tag :integration
  test "handles file system errors gracefully", %{temp_dir: temp_dir} do
    # Try to write to a non-existent directory
    invalid_path = Path.join(temp_dir, "non_existent_dir/plugin.json")

    assert {:ok, plugin_data} = BubbleApi.fetch_plugin()
    json_content = Jason.encode!(plugin_data)

    # This should fail
    assert {:error, _reason} = File.write(invalid_path, json_content)
  end

  test "creates src directory if it doesn't exist", %{src_dir: src_dir} do
    # Verify directory doesn't exist initially
    refute File.exists?(src_dir)

    # Create directory
    File.mkdir_p!(src_dir)

    # Verify directory exists
    assert File.dir?(src_dir)
  end
end
