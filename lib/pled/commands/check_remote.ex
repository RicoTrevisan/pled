defmodule Pled.Commands.CheckRemote do
  @moduledoc """
  Command to check for remote changes without pushing.
  """
  alias Pled.RemoteChecker

  def run(opts \\ []) do
    _verbose? = Keyword.get(opts, :verbose, false)
    
    case RemoteChecker.check_remote_changes() do
      :no_changes ->
        IO.puts(IO.ANSI.green() <> "✓ No remote changes detected" <> IO.ANSI.reset())
        :ok

      {:changes_detected, changes} ->
        IO.puts(IO.ANSI.yellow() <> "⚠ Remote changes detected!" <> IO.ANSI.reset())
        IO.puts("The following changes were found in the remote plugin:")
        IO.puts("")
        
        format_changes(changes)
        
        IO.puts("")
        IO.puts("Recommendations:")
        IO.puts("  • Run 'pled pull' to incorporate remote changes")
        IO.puts("  • Or use 'pled push --force' to overwrite remote changes")
        IO.puts("")
        :ok

      {:error, "No local snapshot found. Run 'pled pull' first to create baseline."} ->
        IO.puts(IO.ANSI.yellow() <> "⚠ No baseline found" <> IO.ANSI.reset())
        IO.puts("Run 'pled pull' first to create a baseline for change detection.")
        :ok

      {:error, reason} ->
        IO.puts(IO.ANSI.red() <> "✗ Failed to check remote changes: #{reason}" <> IO.ANSI.reset())
        {:error, reason}
    end
  end

  defp format_changes(changes) do
    Enum.each(changes, fn change ->
      case change do
        {:metadata_changed, field, old_val, new_val} ->
          IO.puts("  • Metadata '#{field}' changed: '#{old_val}' → '#{new_val}'")
        
        {:element_added, name} ->
          IO.puts("  • Element added: #{name}")
        
        {:element_removed, name} ->
          IO.puts("  • Element removed: #{name}")
        
        {:element_modified, name} ->
          IO.puts("  • Element modified: #{name}")
        
        {:action_added, name} ->
          IO.puts("  • Action added: #{name}")
        
        {:action_removed, name} ->
          IO.puts("  • Action removed: #{name}")
        
        {:action_modified, name} ->
          IO.puts("  • Action modified: #{name}")
        
        _ ->
          IO.puts("  • Unknown change: #{inspect(change)}")
      end
    end)
  end
end