defmodule Pled.FileWatcher do
  @moduledoc """
  GenServer that watches the src/ directory for changes to JavaScript files
  and automatically runs `pled push` when changes are detected.
  """
  use GenServer
  require Logger

  @debounce_ms 500
  @src_dir "src"

  defstruct [:watcher_pid, :debounce_timer]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    if File.exists?(@src_dir) do
      dir = Path.join(File.cwd!(), @src_dir)

      {:ok, watcher_pid} = FileSystem.start_link(dirs: [dir], name: :file_watcher)
      FileSystem.subscribe(:file_watcher)

      state = %{
        watcher_pid: watcher_pid,
        directory_path: dir,
        debounce_timer: nil
      }

      {:ok, state}
    else
      {:error, "#{@src_dir} directory does not exist"}
    end
  end

  @impl true
  def handle_info({:file_event, watcher_pid, {path, events}}, %{watcher_pid: watcher_pid} = state) do
    if should_handle_file?(path, events) do
      IO.puts("File changed: #{path}")

      # Cancel any existing debounce timer
      if state.debounce_timer do
        Process.cancel_timer(state.debounce_timer)
      end

      # Set new debounce timer
      timer = Process.send_after(self(), :run_push, @debounce_ms)
      {:noreply, %{state | debounce_timer: timer}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:file_event, watcher_pid, :stop}, %{watcher_pid: watcher_pid} = state) do
    Logger.info("File watcher stopped")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:run_push, state) do
    IO.puts("Running pled push...")

    case Pled.Commands.Push.run() do
      :ok ->
        IO.puts("Push completed successfully")

      {:error, reason} ->
        IO.puts("Push failed: #{inspect(reason)} - retrying on next change")
    end

    {:noreply, %{state | debounce_timer: nil}}
  end

  @impl true
  def handle_info(msg, state) do
    IO.puts(IO.ANSI.red() <> "Unhandled message: #{inspect(msg)}\nstate: #{inspect(state)}")

    {:noreply, state}
  end

  @impl true
  def terminate(reason, %{watcher_pid: watcher_pid}) when is_pid(watcher_pid) do
    GenServer.stop(watcher_pid)
    Logger.info("FileWatcher terminated: #{inspect(reason)}")
    :ok
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("FileWatcher terminated: #{inspect(reason)}")
    :ok
  end

  # Private functions

  defp should_handle_file?(_path, events) do
    # is_js_file?(path) and
    has_relevant_events?(events)
  end

  defp is_js_file?(path) do
    String.ends_with?(path, ".js")
  end

  defp has_relevant_events?(events) do
    relevant_events = [:created, :modified, :removed]
    Enum.any?(events, &(&1 in relevant_events))
  end
end
