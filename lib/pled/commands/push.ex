defmodule Pled.Commands.Push do
  alias Pled.Commands.Encoder

  def run() do
    IO.puts("Encoding src/ files into dist/")

    case Encoder.encode() do
      :ok ->
        case Pled.BubbleApi.save_plugin() do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
