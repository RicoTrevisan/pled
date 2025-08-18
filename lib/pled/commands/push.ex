defmodule Pled.Commands.Push do
  alias Pled.Commands.Encoder
  alias Pled.RemoteChecker

  def run(opts) do
    # verbose? = Keyword.get(opts, :verbose, false)
    force? = Keyword.get(opts, :force, false)
    IO.puts("pushing")

    # Check for remote changes unless --force is used
    with :ok <- if(force?, do: :ok, else: check_remote_changes()),
         :ok <- Encoder.encode(opts),
         :ok <- Pled.BubbleApi.save_plugin() do
      # Update snapshot after successful push
      case RemoteChecker.update_snapshot() do
        :ok -> :ok
        {:error, _reason} -> :ok  # Don't fail push if snapshot update fails
      end
      
      IO.puts("Push completed")
      :ok
    else
      :abort ->
        IO.puts("Push aborted by user")
        {:error, "Push aborted by user"}
        
      {:error, reason} ->
        IO.puts("Push failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp check_remote_changes do
    case RemoteChecker.check_remote_changes() do
      :no_changes ->
        :ok

      {:changes_detected, changes} ->
        IO.puts("")
        IO.puts(IO.ANSI.yellow() <> "⚠ Remote changes detected!" <> IO.ANSI.reset())
        IO.puts("The following changes were found in the remote plugin:")
        IO.puts("")
        
        format_changes(changes)
        
        IO.puts("")
        IO.puts("Options:")
        IO.puts("  1. Pull first to get remote changes: pled pull")
        IO.puts("  2. Force push (overwrites remote): pled push --force")
        IO.puts("  3. Abort this push")
        IO.puts("")
        
        answer = IO.gets("Continue with push? [y/N]: ") |> String.trim() |> String.downcase()
        
        case answer do
          "y" -> :ok
          "yes" -> :ok
          _ -> :abort
        end

      {:error, "No local snapshot found. Run 'pled pull' first to create baseline."} ->
        IO.puts("")
        IO.puts(IO.ANSI.yellow() <> "⚠ No baseline found" <> IO.ANSI.reset())
        IO.puts("Run 'pled pull' first to create a baseline for change detection.")
        IO.puts("Or use 'pled push --force' to skip this check.")
        IO.puts("")
        
        answer = IO.gets("Continue with push anyway? [y/N]: ") |> String.trim() |> String.downcase()
        
        case answer do
          "y" -> :ok
          "yes" -> :ok
          _ -> :abort
        end

      {:error, reason} ->
        IO.puts("")
        IO.puts(IO.ANSI.red() <> "✗ Failed to check remote changes: #{reason}" <> IO.ANSI.reset())
        IO.puts("Use 'pled push --force' to skip this check.")
        IO.puts("")
        
        answer = IO.gets("Continue with push anyway? [y/N]: ") |> String.trim() |> String.downcase()
        
        case answer do
          "y" -> :ok
          "yes" -> :ok
          _ -> {:error, reason}
        end
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
