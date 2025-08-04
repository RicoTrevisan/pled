defmodule Pled do
  @moduledoc """
  Pled - Bubble.io Plugin Development Tool
  """
  alias Pled.Commands

  @spec main([String.t()]) :: no_return()
  def main(args) do
    case args
         |> parse_args()
         |> handle_command() do
      :ok ->
        System.halt(0)

      {:error, reason} ->
        IO.puts("Command failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  def parse_args(args) do
    case args do
      ["pull" | rest] ->
        {parsed, remaining, invalid} =
          OptionParser.parse(rest,
            strict: [wipe: :boolean, help: :boolean, verbose: :boolean],
            aliases: [w: :wipe, h: :help, v: :verbose]
          )

        if invalid != [] or remaining != [], do: {:help, []}, else: {:pull, parsed}

      ["push" | rest] ->
        {parsed, remaining, invalid} =
          OptionParser.parse(rest,
            strict: [help: :boolean, verbose: :boolean],
            aliases: [h: :help, v: :verbose]
          )

        if invalid != [] or remaining != [], do: {:help, []}, else: {:push, parsed}

      ["encode" | rest] ->
        {parsed, remaining, invalid} =
          OptionParser.parse(rest,
            strict: [help: :boolean, verbose: :boolean],
            aliases: [h: :help, v: :verbose]
          )

        if invalid != [] or remaining != [], do: {:help, []}, else: {:encode, parsed}

      ["upload", file_path | rest] ->
        {parsed, remaining, invalid} =
          OptionParser.parse(rest,
            strict: [help: :boolean, verbose: :boolean],
            aliases: [h: :help, v: :verbose]
          )

        if invalid != [] or remaining != [], do: {:help, []}, else: {:upload, {file_path, parsed}}

      ["start" | rest] ->
        {parsed, remaining, invalid} =
          OptionParser.parse(rest,
            strict: [help: :boolean, verbose: :boolean],
            aliases: [h: :help, v: :verbose]
          )

        if invalid != [] or remaining != [], do: {:help, []}, else: {:start, parsed}

      [] ->
        {:help, []}

      _ ->
        {:help, []}
    end
  end

  def handle_command({:encode, opts}), do: Commands.Encoder.encode(opts)
  def handle_command({:pull, opts}), do: Commands.Pull.run(opts)
  def handle_command({:push, opts}), do: Commands.Push.run(opts)
  def handle_command({:upload, {file_path, opts}}), do: Commands.Upload.run(file_path, opts)
  def handle_command({:start, opts}), do: Commands.Start.run(opts)
  def handle_command({:help, _opts}), do: Commands.Help.run()
end
