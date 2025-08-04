defmodule Pled.Commands.Push do
  alias Pled.Commands.Encoder

  def run(opts) do
    # verbose? = Keyword.get(opts, :verbose, false)
    IO.puts("pushing")

    case Encoder.encode(opts) do
      :ok ->
        case Pled.BubbleApi.save_plugin() do
          :ok ->
            IO.puts("Push completed")
            :ok

          {:error, reason} ->
            IO.puts("Push failed: #{reason}")
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts("Push failed: #{reason}")
        {:error, reason}
    end
  end
end
