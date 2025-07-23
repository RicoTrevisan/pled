defmodule Pled.Commands.Push do
  alias Pled.Commands.Encoder

  def run() do
    if File.exists?("dist/plugin.json") do
      IO.puts("""
          Found file dist/plugin.json.
          Skipping encoding.
      """)
    else
      IO.puts("Encoding src/ files into dist/")
      case Encoder.encode() do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end

    case Pled.BubbleApi.save_plugin() do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
