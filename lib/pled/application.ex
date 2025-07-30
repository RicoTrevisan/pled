defmodule Pled.Application do
  use Application

  @impl true
  def start(_type, _args) do
    env = Application.get_env(:pled, :compile_env)

    if env == :test do
      children = []
      opts = [strategy: :one_for_one, name: Pled.Supervisor]
      Supervisor.start_link(children, opts)
    else
      Burrito.Util.Args.argv()
      |> Pled.main()
    end
  end
end
