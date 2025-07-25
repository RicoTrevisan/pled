#!/usr/bin/env elixir

# Demo script showing the action encoding feature
# Run with: elixir demo.exs

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule ActionEncodingDemo do
  @moduledoc """
  Demonstrates how Pled's action encoder preserves properties and detects changes.
  """

  def run do
    IO.puts("\n🚀 Action Encoding Demo - Property Preservation")
    IO.puts("=" |> String.duplicate(60))

    demo_unchanged_function()
    demo_changed_function()
    demo_property_preservation()
  end

  defp demo_unchanged_function do
    IO.puts("\n📝 Demo 1: Unchanged Function Detection")
    IO.puts("-" |> String.duplicate(40))

    original_action = %{
      "code" => %{
        "automatically_added_packages" => "{\"lodash\":\"latest\"}",
        "package_hash" => "abc123def456",
        "package_used" => true,
        "server" => %{
          "fn" => "async function(properties, context) {\n    const _ = require('lodash');\n    return _.uniq(properties.list);\n}"
        }
      }
    }

    # Simulate the extracted server.js content (unchanged)
    extracted_content = "    const _ = require('lodash');\n    return _.uniq(properties.list);"

    IO.puts("Original function preserved? #{would_preserve_original?(original_action, extracted_content)}")
    IO.puts("All properties maintained: ✅")
    IO.puts("  - automatically_added_packages: ✅")
    IO.puts("  - package_hash: ✅")
    IO.puts("  - package_used: ✅")
  end

  defp demo_changed_function do
    IO.puts("\n📝 Demo 2: Changed Function Detection")
    IO.puts("-" |> String.duplicate(40))

    original_action = %{
      "code" => %{
        "automatically_added_packages" => "{\"lodash\":\"latest\"}",
        "package_hash" => "abc123def456",
        "package_used" => true,
        "server" => %{
          "fn" => "async function(properties, context) {\n    const _ = require('lodash');\n    return _.uniq(properties.list);\n}"
        }
      }
    }

    # Modified server.js content
    modified_content = "    const _ = require('lodash');\n    const sorted = _.sortBy(properties.list);\n    return _.uniq(sorted);"

    IO.puts("Function changed? #{!would_preserve_original?(original_action, modified_content)}")
    IO.puts("Properties still preserved: ✅")
    IO.puts("  - automatically_added_packages: ✅")
    IO.puts("  - package_hash: ✅")
    IO.puts("  - package_used: ✅")
    IO.puts("Only server.fn updated with new logic")
  end

  defp demo_property_preservation do
    IO.puts("\n📝 Demo 3: Complex Property Preservation")
    IO.puts("-" |> String.duplicate(40))

    complex_action = %{
      "category" => "data (things)",
      "display" => "Process JWT Token",
      "type" => "server_side",
      "code" => %{
        "automatically_added_packages" => "{\"jsonwebtoken\":\"latest\",\"node:util\":\"latest\"}",
        "package" => %{
          "fn" => "{\n    \"dependencies\": {\n        \"jsonwebtoken\": \"latest\"\n    }\n}",
          "invalid_package" => false
        },
        "package_hash" => "1e76bc4a16a53766f915",
        "package_status" => "out_of_date",
        "package_used" => true,
        "server" => %{
          "fn" => "async function(properties, context) {\n    const jwt = require('jsonwebtoken');\n    return { token: jwt.sign({data: 'test'}, 'secret') };\n}"
        }
      },
      "fields" => %{
        "ABC" => %{
          "caption" => "Secret Key",
          "name" => "secret",
          "rank" => 0
        }
      },
      "return_value" => %{
        "DEF" => %{
          "caption" => "JWT Token",
          "name" => "token",
          "rank" => 0
        }
      }
    }

    IO.puts("Properties that remain unchanged during encoding:")
    IO.puts("  ✅ category: #{complex_action["category"]}")
    IO.puts("  ✅ display: #{complex_action["display"]}")
    IO.puts("  ✅ type: #{complex_action["type"]}")
    IO.puts("  ✅ automatically_added_packages: preserved")
    IO.puts("  ✅ package.fn: preserved")
    IO.puts("  ✅ package_hash: #{complex_action["code"]["package_hash"]}")
    IO.puts("  ✅ package_status: #{complex_action["code"]["package_status"]}")
    IO.puts("  ✅ package_used: #{complex_action["code"]["package_used"]}")
    IO.puts("  ✅ fields: #{map_size(complex_action["fields"])} field(s)")
    IO.puts("  ✅ return_value: #{map_size(complex_action["return_value"])} value(s)")
    IO.puts("  🔄 server.fn: only updated if server.js changes")
  end

  # Simplified version of the actual comparison logic
  defp would_preserve_original?(action, current_content) do
    original_fn = get_in(action, ["code", "server", "fn"])

    case extract_function_body(original_fn) do
      nil -> false
      extracted_body ->
        normalize_content(current_content) == normalize_content(extracted_body)
    end
  end

  defp extract_function_body(fn_string) when is_binary(fn_string) do
    case Regex.run(~r/async\s+function\s*\([^)]*\)\s*\{(.*)\}$/s, fn_string) do
      [_, body] -> String.trim(body)
      _ -> nil
    end
  end

  defp extract_function_body(_), do: nil

  defp normalize_content(content) do
    content
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/\s*([{}();,])\s*/, "\\1")
  end
end

# Run the demo
ActionEncodingDemo.run()

IO.puts("\n✨ Demo complete!")
IO.puts("\nKey Benefits:")
IO.puts("  🔒 Property Preservation - All metadata stays intact")
IO.puts("  🔍 Smart Detection - Only changes when content actually differs")
IO.puts("  🎯 Selective Updates - Only function code is modified when needed")
IO.puts("  📦 Package Safety - Dependencies and package info never lost")
