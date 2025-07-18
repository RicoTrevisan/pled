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

    code_block = generate_code_block(action_dir)
    json = Map.merge(json, code_block)

    {key, json}
  end

  def generate_code_block(action_dir) do
    action_dir
    |> Path.join("*.js")
    |> Path.wildcard()

    server_js =
      action_dir
      |> Path.join("server.js")

    client_js =
      action_dir
      |> Path.join("client.js")

    generated_functions =
      if File.exists?(server_js) do
        content = File.read!(server_js)

        %{
          "server" => %{
            "fn" => "async function(properties, context) {\n" <> content <> "\n}"
          }
        }
      else
        %{}
      end

    generated_functions =
      if File.exists?(client_js) do
        content = File.read!(client_js)

        generated_functions
        |> Map.merge(%{
          "client" => %{
            "fn" => "function(properties, context) {\n" <> content <> "\n}"
          }
        })
      else
        generated_functions
      end

    %{"code" => generated_functions}
  end
end
