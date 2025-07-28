defmodule Pled.CLI do
  @moduledoc """
  Command line interface for Pled.
  """
  require Logger

  alias Pled.Commands

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

      [] ->
        {:help, []}

      _ ->
        {:help, []}
    end
  end

  def handle_command({:encode, _opts}) do
    case Commands.Encoder.encode() do
      :ok ->
        :ok

      {:error, reason} ->
        IO.warn("Encoding failed, #{inspect(reason)}")
        System.halt(1)
    end
  end

  def handle_command({:pull, opts}) do
    case Commands.Pull.run(opts) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.warn("Pull failed, #{inspect(reason)}")
        System.halt(1)
    end
  end

  def handle_command({:push, _opts}) do
    case Commands.Push.run() do
      :ok ->
        :ok

      {:error, reason} ->
        IO.warn("Push failed, #{inspect(reason)}")
        System.halt(1)
    end
  end

  def handle_command({:upload, file_path}) do
    case Commands.Upload.run(file_path) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.warn("Upload failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  def handle_command({:help, _opts}) do
    case Commands.Help.run() do
      :ok -> :ok
    end
  end
end
