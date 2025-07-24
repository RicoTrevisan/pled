defmodule Pled.Commands.Help do
  def run do
    IO.puts("""
    Pled - Bubble.io Plugin Development Tool
    version #{Application.get_env(:pled, :version)}

    Usage:
      pled pull         Fetch plugin from Bubble.io and save to src/plugin.json
      pled push         Encodes and then upload plugin to Bubble.io (not yet implemented)
      pled enccode      Prepares the files to upload.

    Required Environment Variables:
      PLUGIN_ID         The ID of the plugin to fetch
      COOKIE            Authentication cookie for Bubble.io
    """)

    :ok
  end
end
