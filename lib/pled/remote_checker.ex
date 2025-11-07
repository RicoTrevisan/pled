defmodule Pled.RemoteChecker do
  @moduledoc """
  Module for checking remote changes before pushing to prevent overwrites.

  This module maintains a local snapshot of the remote plugin state in `.src.json`
  and compares it with the current remote state to detect changes.
  """

  alias Pled.{PluginDiff, PluginModel}

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
        diff = PluginDiff.diff(local_snapshot, current_remote)
        {:changes_detected, diff}
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
    PluginModel.equal?(plugin1, plugin2)
  end
end
