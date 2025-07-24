defmodule Pled.CLI do
  @moduledoc """
  Command line interface for Pled.
  """
  require Logger

  alias Pled.Commands

  def parse_args(args) do
    case args do
      ["pull"] -> {:pull, []}
      ["pull" | opts] -> {:pull, opts}
      ["push"] -> {:push, []}
      ["push" | opts] -> {:push, opts}
      ["encode"] -> {:encode, []}
      [] -> {:help, []}
      _ -> {:help, []}
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

  def handle_command({:pull, _opts}) do
    case Commands.Pull.run() do
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

  def handle_command({:help, _opts}) do
    case Commands.Help.run() do
      :ok -> :ok
    end
  end
end
