defmodule Pled.Commands.Encoder.Element do
  def encode_elements(%{} = src_json, opts) do
    IO.puts("checking if plugin has elements...")

    elements_dir =
      opts
      |> Keyword.get(:elements_dir)

    if File.exists?(elements_dir) do
      IO.puts("encoding elements...")

      found_elements =
        elements_dir
        |> File.ls!()

      IO.puts("found elements: #{Enum.map(found_elements, &(&1 <> ", "))}")

      # Process elements and check for errors
      result =
        Enum.reduce_while(
          found_elements,
          {:ok, %{}},
          fn element_dir, {:ok, acc} ->
            case encode_element(Path.join(elements_dir, element_dir)) do
              {:ok, {key, json}} ->
                {:cont, {:ok, Map.put(acc, key, json)}}
              {:error, reason} ->
                {:halt, {:error, reason}}
            end
          end
        )

      case result do
        {:ok, elements} ->
          {:ok, Map.merge(src_json, %{"plugin_elements" => elements})}
        {:error, reason} ->
          IO.puts("\n❌ Element encoding failed: #{reason}")
          {:error, reason}
      end
    else
      IO.puts("no elements found")
      {:ok, src_json}
    end
  end

  def encode_element(element_dir) do
    IO.puts("encoding element #{element_dir}")

    key =
      element_dir
      |> Path.join(".key")
      |> File.read!()

    json =
      element_dir
      |> Path.join("#{key}.json")
      |> File.read!()
      |> Jason.decode!()

    code_block = generate_code_block(element_dir)
    json = Map.merge(json, code_block)

    json = generate_html_headers(json, element_dir)
    
    case update_element_actions_js(json, element_dir) do
      {:error, reason} -> {:error, reason}
      updated_json -> {:ok, {key, updated_json}}
    end
  end

  def generate_html_headers(json, element_dir) do
    html_path = Path.join(element_dir, "headers.html")

    if File.exists?(html_path) do
      snippet = File.read!(html_path)
      Map.merge(json, %{"headers" => %{"snippet" => snippet}})
    else
      json
    end
  end

  def generate_code_block(element_dir) do
    generated_functions =
      [:initialize, :preview, :reset, :update]
      |> Enum.map(fn type ->
        generate_js_file(type, element_dir)
      end)
      |> Enum.reduce(%{}, fn map, acc ->
        Map.merge(acc, map)
      end)

    %{"code" => generated_functions}
  end

  def generate_js_file(:initialize, element_dir) do
    content = File.read!(element_dir |> Path.join("initialize.js"))

    %{
      "initialize" => %{
        "fn" => "function(instance, context) {\n" <> content <> "\n}"
      }
    }
  end

  def generate_js_file(:update, element_dir) do
    content = File.read!(element_dir |> Path.join("update.js"))

    %{
      "update" => %{
        "fn" => "function(instance, properties, context) {\n" <> content <> "\n}"
      }
    }
  end

  def generate_js_file(:preview, element_dir) do
    content = File.read!(element_dir |> Path.join("preview.js"))

    %{
      "preview" => %{
        "fn" => "function(instance, properties) {\n" <> content <> "\n}"
      }
    }
  end

  def generate_js_file(:reset, element_dir) do
    content = File.read!(element_dir |> Path.join("reset.js"))

    %{
      "reset" => %{
        "fn" => "function(instance, context) {\n" <> content <> "\n}"
      }
    }
  end

  def update_element_actions_js(json, element_dir) do
    actions_dir = Path.join(element_dir, "actions")

    if File.exists?(actions_dir) and Map.has_key?(json, "actions") do
      IO.puts("updating element actions from #{actions_dir}")

      # Get existing actions from JSON
      existing_actions = json["actions"]
      
      # Validate and get action files
      js_files = 
        actions_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".js"))

      # Perform bidirectional validation
      validation_result = validate_actions_sync(existing_actions, js_files, actions_dir)
      
      case validation_result do
        {:ok, _} ->
          # Proceed with encoding
          updated_actions =
            js_files
            |> Enum.reduce(existing_actions, fn js_file, acc ->
              update_action_with_js_file(js_file, actions_dir, acc)
            end)

          Map.put(json, "actions", updated_actions)
          
        {:error, :mismatch, details} ->
          IO.puts("\n❌ VALIDATION FAILED: Action count mismatch detected!")
          IO.puts("JSON actions: #{map_size(existing_actions)}")
          IO.puts("JS files: #{length(js_files)}")
          IO.puts("\nDetails:")
          print_validation_details(details)
          
          # Ask user for confirmation with auto-fix option
          IO.puts("\nChoose an action:")
          IO.puts("  y) Continue and auto-fix mismatches")
          IO.puts("  n) Stop encoding (default)")
          IO.write("Choice (y/N): ")
          response = IO.gets("") |> String.trim() |> String.downcase()
          
          if response in ["y", "yes"] do
            IO.puts("Continuing with auto-fix for mismatches...")
            
            # Auto-fix orphaned actions
            fixed_actions = auto_fix_action_mismatches(existing_actions, details, js_files)
            
            updated_actions =
              js_files
              |> Enum.reduce(fixed_actions, fn js_file, acc ->
                update_action_with_js_file(js_file, actions_dir, acc)
              end)

            Map.put(json, "actions", updated_actions)
          else
            IO.puts("Encoding stopped by user. Please fix the action sync issues first.")
            {:error, "user_stopped_validation_mismatch"}
          end
          
        {:error, :validation_failed, errors} ->
          IO.puts("\n❌ VALIDATION FAILED: Critical errors detected!")
          Enum.each(errors, fn error -> IO.puts("  • #{error}") end)
          IO.puts("\nEncoding stopped. Please fix these issues first.")
          {:error, "validation_failed"}
      end
    else
      if File.exists?(actions_dir) and not Map.has_key?(json, "actions") do
        IO.puts("⚠️  Warning: Actions directory exists but no actions found in JSON")
      end
      json
    end
  end

  # New validation function
  defp validate_actions_sync(json_actions, js_files, actions_dir) do
    # Extract keys from JS files
    file_keys = 
      js_files
      |> Enum.map(&extract_key_from_filename/1)
      |> Enum.reject(&is_nil/1)
      
    json_keys = Map.keys(json_actions)
    
    # Check for critical validation errors
    validation_errors = []
    
    # Check for malformed filenames
    malformed_files = 
      js_files
      |> Enum.filter(fn file ->
        is_nil(extract_key_from_filename(file))
      end)
      
    validation_errors = 
      if length(malformed_files) > 0 do
        ["Malformed filenames: #{Enum.join(malformed_files, ", ")}" | validation_errors]
      else
        validation_errors
      end
      
    # Check for empty files
    empty_files =
      js_files
      |> Enum.filter(fn file ->
        js_path = Path.join(actions_dir, file)
        case File.read(js_path) do
          {:ok, content} -> String.trim(content) == ""
          {:error, _} -> true
        end
      end)
      
    validation_errors = 
      if length(empty_files) > 0 do
        ["Empty or unreadable files: #{Enum.join(empty_files, ", ")}" | validation_errors]
      else
        validation_errors
      end
      
    # Check for duplicate keys
    duplicate_keys = 
      file_keys
      |> Enum.frequencies()
      |> Enum.filter(fn {_key, count} -> count > 1 end)
      |> Enum.map(fn {key, count} -> "#{key} (#{count} files)" end)
      
    validation_errors = 
      if length(duplicate_keys) > 0 do
        ["Duplicate action keys: #{Enum.join(duplicate_keys, ", ")}" | validation_errors]
      else
        validation_errors
      end
      
    # If critical errors found, stop immediately
    if length(validation_errors) > 0 do
      {:error, :validation_failed, validation_errors}
    else
      # Check for sync mismatches
      orphaned_files = file_keys -- json_keys
      orphaned_json = json_keys -- file_keys
      
      mismatch_details = %{
        orphaned_files: orphaned_files,
        orphaned_json: orphaned_json,
        json_count: length(json_keys),
        file_count: length(file_keys),
        valid_matches: length(json_keys -- orphaned_json)
      }
      
      if length(orphaned_files) > 0 or length(orphaned_json) > 0 do
        {:error, :mismatch, mismatch_details}
      else
        {:ok, mismatch_details}
      end
    end
  end

  # Enhanced key extraction with better validation
  defp extract_key_from_filename(js_file) do
    case js_file do
      file when is_binary(file) ->
        key = 
          file
          |> String.replace_suffix(".js", "")
          |> String.split("-")
          |> List.last()
          
        # Validate key format (should be 3 uppercase letters)
        if key && String.match?(key, ~r/^[A-Z]{3}$/) do
          key
        else
          nil
        end
      _ -> 
        nil
    end
  end

  # Helper function to print validation details
  defp print_validation_details(details) do
    if length(details.orphaned_files) > 0 do
      IO.puts("  🔸 Orphaned JS files (no matching JSON action):")
      Enum.each(details.orphaned_files, fn key -> 
        IO.puts("    - #{key}")
      end)
    end
    
    if length(details.orphaned_json) > 0 do
      IO.puts("  🔸 Orphaned JSON actions (no matching JS file):")
      Enum.each(details.orphaned_json, fn key -> 
        IO.puts("    - #{key}")
      end)
    end
    
    IO.puts("  📊 Summary:")
    IO.puts("    - Valid matches: #{details.valid_matches}")
    IO.puts("    - Total JSON actions: #{details.json_count}")
    IO.puts("    - Total JS files: #{details.file_count}")
  end

  # Enhanced update function with better error handling
  defp update_action_with_js_file(js_file, actions_dir, actions) do
    try do
      key = extract_key_from_filename(js_file)
      
      if is_nil(key) do
        IO.puts("⚠️  Skipping malformed filename: #{js_file}")
        actions
      else
        # Read the JavaScript content
        js_path = Path.join(actions_dir, js_file)
        
        case File.read(js_path) do
          {:ok, js_content} ->
            # Validate content is not empty
            js_content = if String.trim(js_content) == "" do
              IO.puts("⚠️  Warning: Empty content in #{js_file}, using placeholder")
              "// Empty action file"
            else
              js_content
            end
            
            # Update the action's JavaScript code if the action exists
            if Map.has_key?(actions, key) do
              updated_action =
                actions[key]
                |> put_in(["code", "fn"], "function(instance, properties, context) {\n" <> js_content <> "\n}")

              IO.puts("✅ Updated action #{key} from #{js_file}")
              Map.put(actions, key, updated_action)
            else
              IO.puts("⚠️  Warning: Action with key '#{key}' not found in element JSON, skipping #{js_file}")
              actions
            end
            
          {:error, reason} ->
            IO.puts("❌ Error reading #{js_file}: #{reason}")
            actions
        end
      end
    rescue
      e ->
        IO.puts("❌ Error processing #{js_file}: #{inspect(e)}")
        IO.puts("Skipping this action...")
        actions
    end
  end

  # Auto-fix function to handle orphaned JSON actions and JS files
  defp auto_fix_action_mismatches(existing_actions, details, js_files) do
    IO.puts("\n🔧 Auto-fixing action mismatches...")
    
    # Remove orphaned JSON actions (actions without matching JS files)
    actions_after_deletion = 
      if length(details.orphaned_json) > 0 do
        IO.puts("  🗑️  Removing orphaned JSON actions:")
        Enum.each(details.orphaned_json, fn key -> 
          IO.puts("    - Removing action: #{key}")
        end)
        
        Map.drop(existing_actions, details.orphaned_json)
      else
        existing_actions
      end
    
    # Add missing JSON actions for orphaned JS files
    actions_after_addition =
      if length(details.orphaned_files) > 0 do
        IO.puts("  ➕ Creating JSON actions for orphaned JS files:")
        
        Enum.reduce(details.orphaned_files, actions_after_deletion, fn key, acc ->
          # Find the corresponding JS file to extract the name
          js_file = Enum.find(js_files, fn file ->
            extract_key_from_filename(file) == key
          end)
          
          if js_file do
            # Extract action name from filename (everything before the last dash)
            action_name = 
              js_file
              |> String.replace_suffix(".js", "")
              |> String.split("-")
              |> Enum.drop(-1)  # Remove the key part
              |> Enum.join("-")
              |> String.replace("-", " ")  # Replace dashes with spaces for caption
              |> String.trim()
            
            # Use filename as fallback if name extraction fails
            action_name = if action_name == "", do: String.replace_suffix(js_file, ".js", ""), else: action_name
            
            new_action = %{
              "caption" => action_name,
              "code" => %{
                "fn" => "function(instance, properties, context) {\n// Placeholder - will be updated from #{js_file}\n}"
              }
            }
            
            IO.puts("    - Creating action: #{key} (#{action_name})")
            Map.put(acc, key, new_action)
          else
            IO.puts("    - Warning: Could not find JS file for key #{key}")
            acc
          end
        end)
      else
        actions_after_deletion
      end
    
    IO.puts("✅ Auto-fix completed!")
    IO.puts("  📊 Final summary:")
    IO.puts("    - Removed #{length(details.orphaned_json)} orphaned JSON actions")
    IO.puts("    - Added #{length(details.orphaned_files)} missing JSON actions")
    IO.puts("    - Total actions: #{map_size(actions_after_addition)}")
    
    actions_after_addition
  end

end
