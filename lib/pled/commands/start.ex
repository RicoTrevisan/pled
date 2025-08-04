defmodule Pled.Commands.Start do
  @moduledoc """
  Command to start the file watcher that automatically runs `pled push`
  when JavaScript files in the src/ directory are changed.
  """
  alias Pled.UI

  def run(opts \\ []) do
    verbose? = Keyword.get(opts, :verbose, false)

    try do
      case Pled.FileWatcher.start_link() do
        {:ok, _pid} ->
          UI.logo()
          IO.puts("Started file watcher")
          # Keep the process alive until terminated (Ctrl+C)
          Process.sleep(:infinity)

        {:error, {:already_started, _pid}} ->
          IO.puts("Started file watcher")
          UI.info("File watcher is already running", verbose?)
          Process.sleep(:infinity)

        {:error, reason} ->
          IO.puts("Start failed: #{inspect(reason)}")
          {:error, "Failed to start file watcher: #{inspect(reason)}"}
      end
    catch
      :exit, reason ->
        IO.puts("Start failed: #{inspect(reason)}")
        {:error, "Failed to start file watcher: #{inspect(reason)}"}
    end
  end
end
