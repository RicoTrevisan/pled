defmodule Pled.Commands.StartTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  alias Pled.Commands.Start
  alias Pled.FileWatcher

  setup do
    # Clean up any existing watcher
    if Process.whereis(FileWatcher) do
      FileWatcher.stop()
      Process.sleep(50)
    end

    # Ensure src directory exists for tests
    File.mkdir_p!("src")

    on_exit(fn ->
      if Process.whereis(FileWatcher) do
        FileWatcher.stop()
      end
    end)

    :ok
  end

  describe "run/0" do
    test "starts the file watcher successfully" do
      # Spawn a task to run start command and then stop it
      task = Task.async(fn ->
        capture_io(fn ->
          # Start the file watcher in a separate process
          spawn_link(fn ->
            Start.run()
          end)
          
          # Give it time to start
          Process.sleep(200)
          
          # Verify the FileWatcher process is running
          assert Process.whereis(FileWatcher) != nil
          
          # Stop the watcher
          FileWatcher.stop()
        end)
      end)

      # Wait for task to complete with timeout
      output = Task.await(task, 1000)
      assert output =~ "Watching src/ for changes"
    end

    test "handles error when file watcher fails to start" do
      # Remove src directory to cause failure
      File.rm_rf!("src")
      
      # Since the GenServer crashes on init failure, we need to trap exits
      Process.flag(:trap_exit, true)
      
      # Start.run in a separate process to catch the exit
      pid = spawn_link(fn ->
        result = Start.run()
        send(self(), {:result, result})
      end)
      
      # Wait for either result or exit
      receive do
        {:result, {:error, reason}} ->
          assert reason =~ "Failed to start file watcher"
        
        {:EXIT, ^pid, reason} ->
          # The process exited due to the GenServer crash, which is expected
          assert reason == "src directory does not exist"
      after
        1000 ->
          flunk("Test timed out")
      end
    end

    test "handles already started file watcher" do
      # Start file watcher first
      {:ok, _pid} = FileWatcher.start_link()
      
      # Try to start again
      task = Task.async(fn ->
        capture_io(fn ->
          spawn_link(fn ->
            Start.run()
          end)
          
          Process.sleep(100)
          FileWatcher.stop()
        end)
      end)

      output = Task.await(task, 1000)
      assert output =~ "File watcher is already running"
    end
  end
end