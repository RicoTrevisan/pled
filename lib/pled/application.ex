defmodule Pled.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Pled.CLI

  @impl true
  def start(_type, _args) do
    children = []

    # Only run CLI in production or when built as burrito executable
    if Mix.env() in [:prod, :dev] do
      args = Burrito.Util.Args.argv()

      args
      |> CLI.parse_args()
      |> CLI.handle_command()

      System.halt(0)
    end

    opts = [strategy: :one_for_one, name: Pled.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
