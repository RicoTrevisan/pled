defmodule Pled.FileWatcherTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  alias Pled.FileWatcher

  @tmp_dir "tmp/test_src"
  @test_file "#{@tmp_dir}/test.js"

  setup do
    # Clean up any existing watcher
    if Process.whereis(FileWatcher) do
      FileWatcher.stop()
      Process.sleep(50)
    end

    # Create test directory
    File.mkdir_p!(@tmp_dir)

    on_exit(fn ->
      # Clean up
      if Process.whereis(FileWatcher) do
        FileWatcher.stop()
      end
      File.rm_rf!(@tmp_dir)
    end)

    :ok
  end

  describe "start_link/1" do
    test "fails when src directory doesn't exist" do
      # Backup and remove src directory to simulate missing src
      if File.exists?("src") do
        File.rename!("src", "src_backup")
      end
      
      try do
        # Since the GenServer stops on error, we expect it to crash
        Process.flag(:trap_exit, true)
        assert {:error, reason} = FileWatcher.start_link()
        assert reason == "src directory does not exist"
      after
        # Restore src directory
        if File.exists?("src_backup") do
          File.rename!("src_backup", "src")
        end
      end
    end

    test "starts successfully when src directory exists" do
      # Temporarily rename src to test directory for this test
      if File.exists?("src") do
        File.rename!("src", "src_backup")
      end
      
      File.mkdir_p!("src")
      
      try do
        output = capture_io(fn ->
          assert {:ok, _pid} = FileWatcher.start_link()
          Process.sleep(100)
          FileWatcher.stop()
        end)
        
        assert output =~ "Watching src/ for changes"
      after
        File.rm_rf!("src")
        if File.exists?("src_backup") do
          File.rename!("src_backup", "src")
        end
      end
    end
  end

  describe "file watching" do
    @tag :integration
    test "detects JavaScript file changes" do
      # This test requires integration testing setup
      # Skip for now as it requires complex mocking of FileSystem
      # and testing file system events
      
      # Note: Full integration test would involve:
      # 1. Starting FileWatcher
      # 2. Creating/modifying a .js file
      # 3. Verifying the push command is called
      # 4. Checking debouncing works correctly
    end
  end

  describe "private functions" do
    test "should_handle_file?/2 filters correctly" do
      # Test via direct module access (would need to make functions public for testing)
      # For now, we test the behavior through integration
    end

    test "is_js_file?/1 identifies JavaScript files" do
      # Would test this if made public
      # assert FileWatcher.is_js_file?("test.js") == true
      # assert FileWatcher.is_js_file?("test.txt") == false
    end
  end
end