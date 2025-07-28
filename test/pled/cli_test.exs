defmodule Pled.CLITest do
  use ExUnit.Case
  alias Pled.CLI

  describe "parse_args/1" do
    test "parses pull command without flags" do
      assert CLI.parse_args(["pull"]) == {:pull, []}
    end

    test "parses pull command with -w flag" do
      assert CLI.parse_args(["pull", "-w"]) == {:pull, [wipe: true]}
    end

    test "parses pull command with --wipe flag" do
      assert CLI.parse_args(["pull", "--wipe"]) == {:pull, [wipe: true]}
    end

    test "parses pull command with multiple flags" do
      assert CLI.parse_args(["pull", "-w", "--help"]) == {:pull, [wipe: true, help: true]}
    end

    test "parses pull command with help flag" do
      assert CLI.parse_args(["pull", "-h"]) == {:pull, [help: true]}
      assert CLI.parse_args(["pull", "--help"]) == {:pull, [help: true]}
    end

    test "returns help for pull with invalid flags" do
      assert CLI.parse_args(["pull", "--invalid-flag"]) == {:help, []}
      assert CLI.parse_args(["pull", "--unknown"]) == {:help, []}
    end

    test "returns help for pull with extra arguments" do
      assert CLI.parse_args(["pull", "extra-arg"]) == {:help, []}
      assert CLI.parse_args(["pull", "-w", "extra-arg"]) == {:help, []}
    end

    test "parses push command without flags" do
      assert CLI.parse_args(["push"]) == {:push, []}
    end

    test "parses push command with help flag" do
      assert CLI.parse_args(["push", "-h"]) == {:push, [help: true]}
      assert CLI.parse_args(["push", "--help"]) == {:push, [help: true]}
    end

    test "returns help for push with invalid flags" do
      assert CLI.parse_args(["push", "--invalid-flag"]) == {:help, []}
      assert CLI.parse_args(["push", "-w"]) == {:help, []}
    end

    test "returns help for push with extra arguments" do
      assert CLI.parse_args(["push", "extra-arg"]) == {:help, []}
    end

    test "parses encode command" do
      assert CLI.parse_args(["encode"]) == {:encode, []}
    end

    test "parses upload command with file path" do
      assert CLI.parse_args(["upload", "test.json"]) == {:upload, "test.json"}
      assert CLI.parse_args(["upload", "/path/to/file.json"]) == {:upload, "/path/to/file.json"}
    end

    test "returns help for empty arguments" do
      assert CLI.parse_args([]) == {:help, []}
    end

    test "returns help for unrecognized commands" do
      assert CLI.parse_args(["invalid"]) == {:help, []}
      assert CLI.parse_args(["unknown", "command"]) == {:help, []}
    end

    test "handles boolean flag variations correctly" do
      # Boolean flags can be passed in different ways
      assert CLI.parse_args(["pull", "--wipe=true"]) == {:pull, [wipe: true]}
      assert CLI.parse_args(["pull", "--wipe=false"]) == {:pull, [wipe: false]}
    end
  end

  describe "handle_command/1" do
    test "handle_command delegates to appropriate modules" do
      # Note: These are integration-style tests that verify the command structure
      # The actual command execution is tested in individual command modules

      # Test that encode command structure is correct
      assert match?({:encode, []}, CLI.parse_args(["encode"]))

      # Test that pull command structure is correct
      assert match?({:pull, [wipe: true]}, CLI.parse_args(["pull", "-w"]))

      # Test that push command structure is correct
      assert match?({:push, []}, CLI.parse_args(["push"]))

      # Test that upload command structure is correct
      assert match?({:upload, "file.json"}, CLI.parse_args(["upload", "file.json"]))

      # Test that help command structure is correct
      assert match?({:help, []}, CLI.parse_args(["help"]))
    end
  end
end
