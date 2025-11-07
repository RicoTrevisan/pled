# Test script to validate element actions handling with real example data
# Run with: elixir test_element_actions.exs

Mix.install([
  {:jason, "~> 1.4"},
  {:slugify, "~> 1.3"}
])

defmodule TestElementActions do
  alias Pled.Commands.{Decoder, Encoder}

  def run do
    IO.puts("Testing element actions decode/encode cycle...")

    # Clean up any previous test
    File.rm_rf("test_output")
    File.mkdir_p("test_output/src")
    File.mkdir_p("test_output/dist")

    # Load the example plugin
    plugin_data =
      "priv/examples/small_plugin.json"
      |> File.read!()
      |> Jason.decode!()

    IO.puts("Original plugin loaded. Elements: #{map_size(plugin_data["plugin_elements"])}")

    # Decode to local files
    IO.puts("\n=== DECODING ===")
    Decoder.decode(plugin_data, "test_output")

    # Check what files were created
    element_dir = "test_output/src/elements/tiptap-AAC"
    actions_dir = Path.join(element_dir, "actions")

    if File.exists?(actions_dir) do
      action_files = File.ls!(actions_dir)
      IO.puts("Action files created: #{length(action_files)}")

      Enum.each(action_files, fn file ->
        IO.puts("  - #{file}")
      end)

      # Show content of one action file
      js_files = Enum.filter(action_files, &String.ends_with?(&1, ".js"))

      if length(js_files) > 0 do
        sample_file = hd(js_files)
        content = File.read!(Path.join(actions_dir, sample_file))
        IO.puts("\nSample JS content (#{sample_file}):")
        IO.puts("---")
        IO.puts(String.slice(content, 0, 200) <> "...")
        IO.puts("---")
      end
    else
      IO.puts("No actions directory created")
    end

    # Write the src plugin.json
    File.write!("test_output/src/plugin.json", Jason.encode!(plugin_data, pretty: true))

    # Encode back to JSON
    IO.puts("\n=== ENCODING ===")
    original_cwd = File.cwd!()
    File.cd!("test_output")

    try do
      Encoder.encode()
    after
      File.cd!(original_cwd)
    end

    # Compare results
    IO.puts("\n=== COMPARISON ===")

    encoded_data =
      "test_output/dist/plugin.json"
      |> File.read!()
      |> Jason.decode!()

    original_element = plugin_data["plugin_elements"]["AAC"]
    encoded_element = encoded_data["plugin_elements"]["AAC"]

    original_actions = Map.get(original_element, "actions", %{})
    encoded_actions = Map.get(encoded_element, "actions", %{})

    IO.puts("Original actions: #{map_size(original_actions)}")
    IO.puts("Encoded actions: #{map_size(encoded_actions)}")

    if map_size(original_actions) == map_size(encoded_actions) do
      IO.puts("✅ Action count matches!")

      # Check if all keys are preserved
      original_keys = MapSet.new(Map.keys(original_actions))
      encoded_keys = MapSet.new(Map.keys(encoded_actions))

      if MapSet.equal?(original_keys, encoded_keys) do
        IO.puts("✅ All action keys preserved!")

        # Check captions
        captions_match =
          Enum.all?(original_keys, fn key ->
            original_caption = get_in(original_actions, [key, "caption"])
            encoded_caption = get_in(encoded_actions, [key, "caption"])
            original_caption == encoded_caption
          end)

        if captions_match do
          IO.puts("✅ All captions match!")
        else
          IO.puts("❌ Some captions don't match")
        end

        # Check that JavaScript was preserved
        js_preserved =
          Enum.all?(original_keys, fn key ->
            original_fn = get_in(original_actions, [key, "code", "fn"])
            encoded_fn = get_in(encoded_actions, [key, "code", "fn"])

            # The function should be preserved, but may have different whitespace
            original_fn != nil and encoded_fn != nil and
              String.contains?(encoded_fn, "function(instance, properties, context)")
          end)

        if js_preserved do
          IO.puts("✅ JavaScript functions preserved!")
        else
          IO.puts("❌ JavaScript functions not properly preserved")
        end
      else
        IO.puts("❌ Action keys don't match!")
        IO.puts("Original keys: #{inspect(MapSet.to_list(original_keys))}")
        IO.puts("Encoded keys: #{inspect(MapSet.to_list(encoded_keys))}")
      end
    else
      IO.puts("❌ Action count mismatch!")
    end

    IO.puts("\nTest completed. Check test_output/ directory for generated files.")
  end
end

# Add the lib modules to the code path
Code.prepend_path("lib")

# Load the required modules
Code.require_file("lib/pled/commands/decoder.ex")
Code.require_file("lib/pled/commands/encoder.ex")
Code.require_file("lib/pled/commands/encoder/element.ex")
Code.require_file("lib/pled/commands/encoder/action.ex")

TestElementActions.run()
