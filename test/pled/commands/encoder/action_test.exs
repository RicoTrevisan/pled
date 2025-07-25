defmodule Pled.Commands.Encoder.ActionTest do
  use ExUnit.Case, async: true

  alias Pled.Commands.Encoder.Action

  describe "encode_actions/2" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      # Create actions directory structure
      actions_dir = Path.join(tmp_dir, "actions")
      File.mkdir_p!(actions_dir)

      # Create a sample action
      action_dir = Path.join(actions_dir, "sample-action")
      File.mkdir_p!(action_dir)

      # Write .key file
      File.write!(Path.join(action_dir, ".key"), "ABC")

      # Write action JSON with additional properties to test preservation
      action_json = %{
        "caption" => "Sample Action",
        "code" => %{
          "automatically_added_packages" =>
            "{\"jsonwebtoken\":\"latest\",\"node:util\":\"latest\"}",
          "package" => %{
            "fn" => "{\n    \"dependencies\": {\n        \"jsonwebtoken\": \"latest\"\n    }\n}",
            "invalid_package" => false
          },
          "package_hash" => "1e76bc4a16a53766f915",
          "package_status" => "out_of_date",
          "package_used" => true,
          "server" => %{
            "fn" =>
              "async function(properties, context) {\n    console.log('original server code');\n    return { message: 'hello' };\n}"
          },
          "client" => %{
            "fn" => "function(properties, context) {\n    console.log('original client code');\n}"
          }
        }
      }

      File.write!(Path.join(action_dir, "ABC.json"), Jason.encode!(action_json))

      # Write JS files with original content (extracted from the functions)
      File.write!(
        Path.join(action_dir, "server.js"),
        "    console.log('original server code');\n    return { message: 'hello' };"
      )

      File.write!(Path.join(action_dir, "client.js"), "    console.log('original client code');")

      src_json = %{"plugin_actions" => %{}}
      opts = [actions_dir: actions_dir]

      {:ok, src_json: src_json, opts: opts, action_dir: action_dir, action_json: action_json}
    end

    test "uses original function when JS files are unchanged", %{
      src_json: src_json,
      opts: opts,
      action_json: action_json
    } do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          result = Action.encode_actions(src_json, opts)
          send(self(), {:result, result})
        end)

      assert_received {:result, result}

      # Check console output indicates original functions were used
      assert output =~ "Using original server function (no changes detected)"
      assert output =~ "Using original client function (no changes detected)"

      # Verify the exact original functions are preserved
      encoded_action = result["plugin_actions"]["ABC"]
      assert encoded_action["code"]["server"]["fn"] == action_json["code"]["server"]["fn"]
      assert encoded_action["code"]["client"]["fn"] == action_json["code"]["client"]["fn"]

      # Verify all other code properties are preserved
      assert encoded_action["code"]["automatically_added_packages"] ==
               action_json["code"]["automatically_added_packages"]

      assert encoded_action["code"]["package"] == action_json["code"]["package"]
      assert encoded_action["code"]["package_hash"] == action_json["code"]["package_hash"]
      assert encoded_action["code"]["package_status"] == action_json["code"]["package_status"]
      assert encoded_action["code"]["package_used"] == action_json["code"]["package_used"]
    end

    test "uses modified function when server.js is changed", %{
      src_json: src_json,
      opts: opts,
      action_dir: action_dir,
      action_json: action_json
    } do
      import ExUnit.CaptureIO

      # Modify server.js
      File.write!(
        Path.join(action_dir, "server.js"),
        "    console.log('modified server code');\n    return { message: 'modified' };"
      )

      output =
        capture_io(fn ->
          result = Action.encode_actions(src_json, opts)
          send(self(), {:result, result})
        end)

      assert_received {:result, result}

      # Check console output
      assert output =~ "Using modified server function from server.js"
      assert output =~ "Using original client function (no changes detected)"

      # Verify the server function was updated but other properties preserved
      encoded_action = result["plugin_actions"]["ABC"]
      server_fn = encoded_action["code"]["server"]["fn"]
      assert server_fn =~ "modified server code"
      assert server_fn =~ "async function(properties, context)"

      # Verify all other code properties are still preserved
      assert encoded_action["code"]["automatically_added_packages"] ==
               action_json["code"]["automatically_added_packages"]

      assert encoded_action["code"]["package"] == action_json["code"]["package"]
      assert encoded_action["code"]["package_hash"] == action_json["code"]["package_hash"]
    end

    test "uses modified function when client.js is changed", %{
      src_json: src_json,
      opts: opts,
      action_dir: action_dir,
      action_json: action_json
    } do
      import ExUnit.CaptureIO

      # Modify client.js
      File.write!(
        Path.join(action_dir, "client.js"),
        "    console.log('modified client code');\n    alert('hello');"
      )

      output =
        capture_io(fn ->
          result = Action.encode_actions(src_json, opts)
          send(self(), {:result, result})
        end)

      assert_received {:result, result}

      # Check console output
      assert output =~ "Using original server function (no changes detected)"
      assert output =~ "Using modified client function from client.js"

      # Verify only client function was updated, everything else preserved
      encoded_action = result["plugin_actions"]["ABC"]
      assert encoded_action["code"]["server"]["fn"] == action_json["code"]["server"]["fn"]

      client_fn = encoded_action["code"]["client"]["fn"]
      assert client_fn =~ "modified client code"
      assert client_fn =~ "function(properties, context)"

      # Verify all other code properties are still preserved
      assert encoded_action["code"]["automatically_added_packages"] ==
               action_json["code"]["automatically_added_packages"]

      assert encoded_action["code"]["package"] == action_json["code"]["package"]
      assert encoded_action["code"]["package_hash"] == action_json["code"]["package_hash"]
    end

    test "handles whitespace differences correctly", %{
      src_json: src_json,
      opts: opts,
      action_json: action_json,
      action_dir: action_dir
    } do
      import ExUnit.CaptureIO

      # Write JS with different whitespace but same logic
      File.write!(
        Path.join(action_dir, "server.js"),
        "    console.log(  'original server code'  )  ;\n    return   {   message:   'hello'   }  ;"
      )

      output =
        capture_io(fn ->
          result = Action.encode_actions(src_json, opts)
          send(self(), {:result, result})
        end)

      assert_received {:result, result}

      # Should detect as unchanged due to normalization
      assert output =~ "Using original server function (no changes detected)"

      encoded_action = result["plugin_actions"]["ABC"]
      assert encoded_action["code"]["server"]["fn"] == action_json["code"]["server"]["fn"]
    end

    test "handles missing JS files", %{
      src_json: src_json,
      opts: opts,
      action_dir: action_dir,
      action_json: action_json
    } do
      import ExUnit.CaptureIO

      # Delete JS files
      File.rm!(Path.join(action_dir, "server.js"))
      File.rm!(Path.join(action_dir, "client.js"))

      _output =
        capture_io(fn ->
          result = Action.encode_actions(src_json, opts)
          send(self(), {:result, result})
        end)

      assert_received {:result, result}

      # Should preserve non-function properties when JS files are missing
      encoded_action = result["plugin_actions"]["ABC"]

      # Should not have server or client functions, but preserve other properties
      assert Map.has_key?(encoded_action["code"], "server") == false
      assert Map.has_key?(encoded_action["code"], "client") == false

      # Should preserve all other properties
      assert encoded_action["code"]["automatically_added_packages"] ==
               action_json["code"]["automatically_added_packages"]

      assert encoded_action["code"]["package"] == action_json["code"]["package"]
      assert encoded_action["code"]["package_hash"] == action_json["code"]["package_hash"]
      assert encoded_action["code"]["package_status"] == action_json["code"]["package_status"]
      assert encoded_action["code"]["package_used"] == action_json["code"]["package_used"]
    end

    test "handles actions without original code", %{
      src_json: src_json,
      opts: opts,
      action_dir: action_dir
    } do
      import ExUnit.CaptureIO

      # Create action JSON without code block
      action_json_no_code = %{
        "caption" => "Sample Action"
      }

      File.write!(Path.join(action_dir, "ABC.json"), Jason.encode!(action_json_no_code))

      output =
        capture_io(fn ->
          result = Action.encode_actions(src_json, opts)
          send(self(), {:result, result})
        end)

      assert_received {:result, result}

      # Should create new functions from JS files
      assert output =~ "Using modified server function from server.js"
      assert output =~ "Using modified client function from client.js"

      encoded_action = result["plugin_actions"]["ABC"]
      assert encoded_action["code"]["server"]["fn"] =~ "async function(properties, context)"
      assert encoded_action["code"]["client"]["fn"] =~ "function(properties, context)"
    end

    test "encodes multiple actions", %{tmp_dir: tmp_dir} do
      import ExUnit.CaptureIO

      # Create a fresh actions directory for this test
      actions_dir = Path.join(tmp_dir, "multi_actions")
      File.mkdir_p!(actions_dir)

      # Create multiple actions
      for {key, name} <- [{"ABC", "Action One"}, {"DEF", "Action Two"}] do
        action_dir =
          Path.join(actions_dir, "#{String.downcase(name) |> String.replace(" ", "-")}")

        File.mkdir_p!(action_dir)
        File.write!(Path.join(action_dir, ".key"), key)

        action_json = %{
          "caption" => name,
          "code" => %{
            "server" => %{
              "fn" => "async function(properties, context) {\n    // #{name} server\n}"
            }
          }
        }

        File.write!(Path.join(action_dir, "#{key}.json"), Jason.encode!(action_json))
        File.write!(Path.join(action_dir, "server.js"), "    // #{name} server")
      end

      src_json = %{"plugin_actions" => %{}}
      opts = [actions_dir: actions_dir]

      output =
        capture_io(fn ->
          result = Action.encode_actions(src_json, opts)
          send(self(), {:result, result})
        end)

      assert_received {:result, result}

      # Should have both actions
      assert Map.keys(result["plugin_actions"]) |> Enum.sort() == ["ABC", "DEF"]

      # Both should use original functions
      assert output =~ "Using original server function (no changes detected)"
      # Count occurrences - should be one per action
      occurrences = Regex.scan(~r/Using original server function/, output)
      assert length(occurrences) == 2
    end

    test "preserves complex action properties from real plugin", %{tmp_dir: tmp_dir} do
      import ExUnit.CaptureIO

      actions_dir = Path.join(tmp_dir, "complex_actions")
      File.mkdir_p!(actions_dir)

      # Create action with all the properties from the real example
      action_dir = Path.join(actions_dir, "generate-jwt-key")
      File.mkdir_p!(action_dir)

      File.write!(Path.join(action_dir, ".key"), "AEK")

      # Complex action JSON with all properties
      complex_action_json = %{
        "category" => "data (things)",
        "code" => %{
          "automatically_added_packages" =>
            "{\"jsonwebtoken\":\"latest\",\"node:util\":\"latest\"}",
          "package" => %{
            "fn" => "{\n    \"dependencies\": {\n        \"jsonwebtoken\": \"latest\"\n    }\n}",
            "invalid_package" => false
          },
          "package_hash" => "1e76bc4a16a53766f915",
          "package_status" => "out_of_date",
          "package_used" => true,
          "server" => %{
            "fn" =>
              "async function(properties, context) {\n\n\n\n    const jsonwebtoken = require('jsonwebtoken');\n    const { inspect } = require('node:util');\n\n    const doc = properties.docID;\n    const docList = properties.docIDList;\n\n    let allowedDocumentNames = [];\n\tif (!!doc) allowedDocumentNames.push(doc);\n\tif (!!docList) allowedDocumentNames.push(docList);\n    const data = {\n        allowedDocumentNames: allowedDocumentNames\n    }\n    let key;\n    if (properties.jwt_secret === \"Tiptap Cloud\") key = context.keys[\"Tiptap Cloud JWT secret\"]\n    if (properties.jwt_secret === \"Custom\") key = context.keys[\"Custom collab JWT secret\"]\n\n    try {\n        const jwt = jsonwebtoken.sign(data, key);\n\n        return {\n            jwt_key: jwt,\n            error: \"\",\n            returned_an_error: false\n\n        }\n    } catch (error) {\n        console.log(\"error when creating JWT token\", inspect(error) );\n        return {\n            jwt_key: \"\",\n            error: \"there was an error retrieving the jwt keys.\\n\" + inspect(error),\n            returned_an_error: true\n        }\n\n    }\n\n\n\n\n\n\n\n\n}"
          }
        },
        "display" => "generate JWT key",
        "fields" => %{
          "AEL" => %{
            "caption" => "Doc ID",
            "doc" =>
              "the document's unique ID. This will be the name of the document that you will see on 𝗵𝘁𝘁𝗽𝘀://𝗰𝗼𝗹𝗹𝗮𝗯.𝘁𝗶𝗽𝘁𝗮𝗽.𝗱𝗲𝘃",
            "editor" => "DynamicValue",
            "name" => "docID",
            "optional" => true,
            "rank" => 0,
            "value" => "text"
          }
        },
        "return_value" => %{
          "AEM" => %{
            "caption" => "jwt key",
            "name" => "jwt_key",
            "rank" => 0,
            "value" => "text"
          }
        },
        "type" => "server_side"
      }

      File.write!(Path.join(action_dir, "AEK.json"), Jason.encode!(complex_action_json))

      # Extract function body and write to server.js (unchanged from original)
      original_body =
        "\n\n\n\n    const jsonwebtoken = require('jsonwebtoken');\n    const { inspect } = require('node:util');\n\n    const doc = properties.docID;\n    const docList = properties.docIDList;\n\n    let allowedDocumentNames = [];\n\tif (!!doc) allowedDocumentNames.push(doc);\n\tif (!!docList) allowedDocumentNames.push(docList);\n    const data = {\n        allowedDocumentNames: allowedDocumentNames\n    }\n    let key;\n    if (properties.jwt_secret === \"Tiptap Cloud\") key = context.keys[\"Tiptap Cloud JWT secret\"]\n    if (properties.jwt_secret === \"Custom\") key = context.keys[\"Custom collab JWT secret\"]\n\n    try {\n        const jwt = jsonwebtoken.sign(data, key);\n\n        return {\n            jwt_key: jwt,\n            error: \"\",\n            returned_an_error: false\n\n        }\n    } catch (error) {\n        console.log(\"error when creating JWT token\", inspect(error) );\n        return {\n            jwt_key: \"\",\n            error: \"there was an error retrieving the jwt keys.\\n\" + inspect(error),\n            returned_an_error: true\n        }\n\n    }\n\n\n\n\n\n\n\n\n"

      File.write!(Path.join(action_dir, "server.js"), original_body)

      src_json = %{"plugin_actions" => %{}}
      opts = [actions_dir: actions_dir]

      output =
        capture_io(fn ->
          result = Action.encode_actions(src_json, opts)
          send(self(), {:result, result})
        end)

      assert_received {:result, result}

      # Should use original function since unchanged
      assert output =~ "Using original server function (no changes detected)"

      encoded_action = result["plugin_actions"]["AEK"]

      # Verify ALL properties are preserved
      assert encoded_action["category"] == "data (things)"
      assert encoded_action["display"] == "generate JWT key"
      assert encoded_action["type"] == "server_side"

      # Verify all code properties are preserved
      code = encoded_action["code"]
      original_code = complex_action_json["code"]

      assert code["automatically_added_packages"] == original_code["automatically_added_packages"]
      assert code["package"] == original_code["package"]
      assert code["package_hash"] == original_code["package_hash"]
      assert code["package_status"] == original_code["package_status"]
      assert code["package_used"] == original_code["package_used"]
      assert code["server"]["fn"] == original_code["server"]["fn"]

      # Verify fields and return_value are preserved
      assert encoded_action["fields"] == complex_action_json["fields"]
      assert encoded_action["return_value"] == complex_action_json["return_value"]
    end
  end

  describe "generate_code_block/2" do
    @describetag :tmp_dir
    setup %{tmp_dir: tmp_dir} do
      original_json = %{
        "code" => %{
          "server" => %{
            "fn" => "async function(properties, context) {\n    return { original: true };\n}"
          },
          "client" => %{
            "fn" => "function(properties, context) {\n    console.log('original');\n}"
          }
        }
      }

      {:ok, action_dir: tmp_dir, original_json: original_json}
    end

    test "returns empty map when no JS files exist", %{
      action_dir: action_dir,
      original_json: original_json
    } do
      result = Action.generate_code_block(action_dir, original_json)
      # Should preserve non-function properties but remove server/client functions
      expected_code = original_json["code"] |> Map.drop(["server", "client"])
      assert result == %{"code" => expected_code}
    end

    test "generates server function only", %{action_dir: action_dir, original_json: original_json} do
      File.write!(Path.join(action_dir, "server.js"), "    return { modified: true };")

      result = Action.generate_code_block(action_dir, original_json)

      assert Map.keys(result["code"]) == ["server"]
      assert result["code"]["server"]["fn"] =~ "modified: true"
    end

    test "generates client function only", %{action_dir: action_dir, original_json: original_json} do
      File.write!(Path.join(action_dir, "client.js"), "    console.log('modified');")

      result = Action.generate_code_block(action_dir, original_json)

      assert Map.keys(result["code"]) == ["client"]
      assert result["code"]["client"]["fn"] =~ "modified"
    end

    test "preserves original when no code section exists", %{action_dir: action_dir} do
      File.write!(Path.join(action_dir, "server.js"), "    return { new: true };")

      # Pass JSON without code section
      result = Action.generate_code_block(action_dir, %{})

      # Should still generate new function
      assert result["code"]["server"]["fn"] =~ "new: true"
    end
  end
end
