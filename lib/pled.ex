defmodule Pled do
  @moduledoc """
  Pled - Bubble.io Plugin Development Tool
  """
  require Logger

  alias Pled.Commands

  @spec main([String.t()]) :: no_return()
  def main(args) do
    case args
         |> parse_args()
         |> handle_command() do
      :ok ->
        System.halt(0)

      {:error, reason} ->
        IO.warn("Command failed, #{inspect(reason)}")
        System.halt(1)
    end
  end

  def parse_args(args) do
    case args do
      ["pull" | rest] ->
        {parsed, remaining, invalid} =
          OptionParser.parse(rest,
            strict: [wipe: :boolean, help: :boolean],
            aliases: [w: :wipe, h: :help]
          )

        if invalid != [] or remaining != [], do: {:help, []}, else: {:pull, parsed}

      ["push" | rest] ->
        {parsed, remaining, invalid} =
          OptionParser.parse(rest,
            strict: [help: :boolean],
            aliases: [h: :help]
          )

        if invalid != [] or remaining != [], do: {:help, []}, else: {:push, parsed}

      ["encode"] ->
        {:encode, []}

      ["upload", file_path] ->
        {:upload, file_path}

      ["start"] ->
        IO.puts(IO.ANSI.blue_background() <> "Starting file watcher" <> IO.ANSI.reset())
        IO.puts("hit Ctrl+C twice to stop")
        {:start, []}

      [] ->
        {:help, []}

      _ ->
        {:help, []}
    end
  end

  def handle_command({:encode, _opts}), do: Commands.Encoder.encode()
  def handle_command({:pull, opts}), do: Commands.Pull.run(opts)
  def handle_command({:push, _opts}), do: Commands.Push.run()
  def handle_command({:upload, file_path}), do: Commands.Upload.run(file_path)
  def handle_command({:start, _opts}), do: Commands.Start.run()
  def handle_command({:help, _opts}), do: Commands.Help.run()
end
