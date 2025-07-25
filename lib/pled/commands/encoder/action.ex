defmodule Pled.Commands.Encoder.Action do
  def encode_actions(%{} = src_json, opts) do
    actions_dir = opts |> Keyword.get(:actions_dir)

    actions =
      if File.exists?(actions_dir) do
        actions_dir
        |> File.ls!()
        |> Enum.reduce(
          %{},
          fn action_dir, acc ->
            {key, json} = encode_action(Path.join(actions_dir, action_dir))
            Map.put(acc, key, json)
          end
        )
      else
        %{}
      end

    Map.put(src_json, "plugin_actions", actions)
  end

  def encode_action(action_dir) do
    IO.puts("encoding action #{action_dir}")

    key =
      action_dir
      |> Path.join(".key")
      |> File.read!()

    json =
      action_dir
      |> Path.join("#{key}.json")
      |> File.read!()
      |> Jason.decode!()

    code_block = generate_code_block(action_dir, json)
    json = Map.merge(json, code_block)

    {key, json}
  end

  def generate_code_block(action_dir, original_json) do
    # Get original functions from JSON if they exist
    original_code = Map.get(original_json, "code", %{})
    original_server_fn = get_in(original_code, ["server", "fn"])
    original_client_fn = get_in(original_code, ["client", "fn"])

    server_js =
      action_dir
      |> Path.join("server.js")

    client_js =
      action_dir
      |> Path.join("client.js")

    # Start with only the non-function properties from original code
    base_properties = Map.drop(original_code, ["server", "client"])

    # Process server function
    updated_code =
      if File.exists?(server_js) do
        content = File.read!(server_js)

        # Get existing server code block or create empty one
        existing_server = Map.get(original_code, "server", %{})

        # Check if the content matches the original (after extracting function body)
        if should_use_original_function?(content, original_server_fn, :server) do
          IO.puts("  ↻ Using original server function (no changes detected)")

          # Keep the existing server block as-is
          Map.put(base_properties, "server", existing_server)
        else
          IO.puts("  ✏️  Using modified server function from server.js")

          # Update only the server function
          Map.put(
            base_properties,
            "server",
            Map.put(
              existing_server,
              "fn",
              "async function(properties, context) {\n" <> content <> "\n}"
            )
          )
        end
      else
        base_properties
      end

    # Process client function
    updated_code =
      if File.exists?(client_js) do
        content = File.read!(client_js)

        # Get existing client code block or create empty one
        existing_client = Map.get(original_code, "client", %{})

        # Check if the content matches the original (after extracting function body)
        if should_use_original_function?(content, original_client_fn, :client) do
          IO.puts("  ↻ Using original client function (no changes detected)")

          # Keep the existing client block as-is
          Map.put(updated_code, "client", existing_client)
        else
          IO.puts("  ✏️  Using modified client function from client.js")

          # Update only the client function
          Map.put(
            updated_code,
            "client",
            Map.put(
              existing_client,
              "fn",
              "function(properties, context) {\n" <> content <> "\n}"
            )
          )
        end
      else
        updated_code
      end

    %{"code" => updated_code}
  end

  defp should_use_original_function?(current_content, original_fn, type)
       when is_binary(original_fn) do
    # Extract the body from the original function
    extracted_body = extract_function_body(original_fn, type)

    # Normalize both contents for comparison (remove extra whitespace, etc.)
    normalized_current = normalize_content(current_content)
    normalized_original = normalize_content(extracted_body)

    # Return true if they match (meaning no changes were made)
    normalized_current == normalized_original
  end

  defp should_use_original_function?(_current_content, _original_fn, _type), do: false

  defp extract_function_body(fn_string, :server) do
    # For server functions: async function(properties, context) { ... }
    case Regex.run(~r/async\s+function\s*\([^)]*\)\s*\{(.*)\}$/s, fn_string) do
      [_, body] -> String.trim(body)
      _ -> ""
    end
  end

  defp extract_function_body(fn_string, :client) do
    # For client functions: function(properties, context) { ... }
    case Regex.run(~r/function\s*\([^)]*\)\s*\{(.*)\}$/s, fn_string) do
      [_, body] -> String.trim(body)
      _ -> ""
    end
  end

  defp normalize_content(content) do
    content
    |> String.trim()
    # Replace multiple whitespaces with single space
    |> String.replace(~r/\s+/, " ")
    # Remove spaces around delimiters
    |> String.replace(~r/\s*([{}();,])\s*/, "\\1")
  end
end
