defmodule Pled.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Pled.CLI

  @impl true
  def start(_type, _args) do
    IO.puts("Starting Pled Application...")
    args = Burrito.Util.Args.argv() |> dbg()
    IO.inspect(args)
    # For CLI applications, we don't want to start a supervisor tree
    # Just return an error to prevent the application from staying alive

    args
    |> CLI.parse_args()
    |> CLI.handle_command()

    System.halt(0)
    :ok
  end
end
