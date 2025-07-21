defmodule Pled.Commands.Push do
  alias Pled.Commands.Encoder

  def run() do
    IO.puts("Encoding src/ files into dist/")

    Encoder.encode()
    Pled.BubbleApi.save_plugin()
    System.halt(0)
  end
end
