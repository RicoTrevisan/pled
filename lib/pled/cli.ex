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

  def handle_command({:encode, _opts}), do: Commands.Encoder.encode()

  def handle_command({:pull, _opts}), do: Commands.Pull.run()

  def handle_command({:push, _opts}), do: Commands.Push.run()

  def handle_command({:help, _opts}), do: Commands.Help.run()
end
