defmodule Pled.Commands.Start do
  @moduledoc """
  Command to start the file watcher that automatically runs `pled push`
  when JavaScript files in the src/ directory are changed.
  """

  def run() do
    try do
      case Pled.FileWatcher.start_link() do
        {:ok, _pid} ->
          # Keep the process alive until terminated (Ctrl+C)
          Process.sleep(:infinity)

        {:error, {:already_started, _pid}} ->
          IO.puts("File watcher is already running")
          Process.sleep(:infinity)

        {:error, reason} ->
          {:error, "Failed to start file watcher: #{inspect(reason)}"}
      end
    catch
      :exit, reason ->
        {:error, "Failed to start file watcher: #{inspect(reason)}"}
    end
  end
end
