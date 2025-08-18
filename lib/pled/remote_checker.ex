defmodule Pled.RemoteChecker do
  @moduledoc """
  Module for checking remote changes before pushing to prevent overwrites.
  
  This module maintains a local snapshot of the remote plugin state in `.src.json`
  and compares it with the current remote state to detect changes.
  """

  defp snapshot_file_path do
    Application.get_env(:pled, :src_snapshot_file, ".src.json")
  end

  @doc """
  Checks if the remote plugin has changed since the last pull.
  
  Returns:
  - `:no_changes` if remote hasn't changed
  - `{:changes_detected, changes}` if remote has changed
  - `{:error, reason}` if check failed
  """
  def check_remote_changes do
    with {:ok, current_remote} <- fetch_current_remote(),
         {:ok, local_snapshot} <- read_local_snapshot() do
      if plugins_equal?(current_remote, local_snapshot) do
        :no_changes
      else
        changes = analyze_changes(local_snapshot, current_remote)
        {:changes_detected, changes}
      end
    else
      {:error, :no_snapshot} ->
        {:error, "No local snapshot found. Run 'pled pull' first to create baseline."}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Saves the current remote plugin data as a local snapshot.
  
  This should be called after every successful pull operation.
  """
  def save_remote_snapshot(plugin_data) do
    json_content = Jason.encode!(plugin_data, pretty: true)
    
    case File.write(snapshot_file_path(), json_content) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to save snapshot: #{reason}"}
    end
  end

  @doc """
  Quick boolean check if remote has changed.
  """
  def has_remote_changed? do
    case check_remote_changes() do
      :no_changes -> false
      {:changes_detected, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Gets detailed information about what changed in the remote.
  """
  def get_remote_changes do
    case check_remote_changes() do
      {:changes_detected, changes} -> {:ok, changes}
      :no_changes -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates the local snapshot to match current remote state.
  
  This effectively "acknowledges" remote changes.
  """
  def update_snapshot do
    case fetch_current_remote() do
      {:ok, remote_data} -> save_remote_snapshot(remote_data)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks if snapshot file exists.
  """
  def snapshot_exists? do
    File.exists?(snapshot_file_path())
  end

  # Private functions

  defp fetch_current_remote do
    case Pled.BubbleApi.fetch_plugin() do
      {:ok, plugin_data} -> {:ok, plugin_data}
      {:error, reason} -> {:error, "Failed to fetch remote: #{reason}"}
    end
  end

  defp read_local_snapshot do
    case File.read(snapshot_file_path()) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, "Invalid snapshot JSON: #{reason}"}
        end
      
      {:error, :enoent} ->
        {:error, :no_snapshot}
      
      {:error, reason} ->
        {:error, "Failed to read snapshot: #{reason}"}
    end
  end

  defp plugins_equal?(plugin1, plugin2) do
    # Deep comparison of plugin data structures
    # We use Jason to normalize the comparison since both should be valid JSON
    normalize_plugin(plugin1) == normalize_plugin(plugin2)
  end

  defp normalize_plugin(plugin) do
    # Convert to JSON and back to ensure consistent structure
    plugin
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp analyze_changes(old_plugin, new_plugin) do
    changes = []
    
    # Check top-level metadata changes
    changes = check_metadata_changes(old_plugin, new_plugin, changes)
    
    # Check elements changes
    changes = check_elements_changes(old_plugin, new_plugin, changes)
    
    # Check actions changes
    changes = check_actions_changes(old_plugin, new_plugin, changes)
    
    changes
  end

  defp check_metadata_changes(old_plugin, new_plugin, changes) do
    metadata_fields = ["name", "description", "version", "author"]
    
    Enum.reduce(metadata_fields, changes, fn field, acc ->
      old_val = get_in(old_plugin, [field])
      new_val = get_in(new_plugin, [field])
      
      if old_val != new_val do
        [{:metadata_changed, field, old_val, new_val} | acc]
      else
        acc
      end
    end)
  end

  defp check_elements_changes(old_plugin, new_plugin, changes) do
    old_elements = get_in(old_plugin, ["elements"]) || []
    new_elements = get_in(new_plugin, ["elements"]) || []
    
    old_element_map = Map.new(old_elements, fn el -> {el["name"], el} end)
    new_element_map = Map.new(new_elements, fn el -> {el["name"], el} end)
    
    # Check for added elements
    added = Map.keys(new_element_map) -- Map.keys(old_element_map)
    changes = Enum.reduce(added, changes, fn name, acc ->
      [{:element_added, name} | acc]
    end)
    
    # Check for removed elements
    removed = Map.keys(old_element_map) -- Map.keys(new_element_map)
    changes = Enum.reduce(removed, changes, fn name, acc ->
      [{:element_removed, name} | acc]
    end)
    
    # Check for modified elements
    common = Map.keys(old_element_map) -- (added ++ removed)
    Enum.reduce(common, changes, fn name, acc ->
      old_el = old_element_map[name]
      new_el = new_element_map[name]
      
      if old_el != new_el do
        [{:element_modified, name} | acc]
      else
        acc
      end
    end)
  end

  defp check_actions_changes(old_plugin, new_plugin, changes) do
    old_actions = get_in(old_plugin, ["actions"]) || []
    new_actions = get_in(new_plugin, ["actions"]) || []
    
    old_action_map = Map.new(old_actions, fn action -> {action["name"], action} end)
    new_action_map = Map.new(new_actions, fn action -> {action["name"], action} end)
    
    # Check for added actions
    added = Map.keys(new_action_map) -- Map.keys(old_action_map)
    changes = Enum.reduce(added, changes, fn name, acc ->
      [{:action_added, name} | acc]
    end)
    
    # Check for removed actions
    removed = Map.keys(old_action_map) -- Map.keys(new_action_map)
    changes = Enum.reduce(removed, changes, fn name, acc ->
      [{:action_removed, name} | acc]
    end)
    
    # Check for modified actions
    common = Map.keys(old_action_map) -- (added ++ removed)
    Enum.reduce(common, changes, fn name, acc ->
      old_action = old_action_map[name]
      new_action = new_action_map[name]
      
      if old_action != new_action do
        [{:action_modified, name} | acc]
      else
        acc
      end
    end)
  end
end