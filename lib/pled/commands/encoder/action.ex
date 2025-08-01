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
      else
        base_properties
      end

    # Process client function
    updated_code =
      if File.exists?(client_js) do
        content = File.read!(client_js)

        # Get existing client code block or create empty one
        existing_client = Map.get(original_code, "client", %{})

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
      else
        updated_code
      end

    %{"code" => updated_code}
  end
end
