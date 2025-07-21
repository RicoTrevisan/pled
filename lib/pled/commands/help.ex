defmodule Pled.Commands.Help do
  def run do
    IO.puts("""
    Pled - Bubble.io Plugin Development Tool
    version 0.0.1

    Usage:
      pled pull    Fetch plugin from Bubble.io and save to src/plugin.json
      pled push    Upload plugin to Bubble.io (not yet implemented)

    Required Environment Variables:
      PLUGIN_ID    The ID of the plugin to fetch
      COOKIE       Authentication cookie for Bubble.io
    """)

    System.halt(0)
  end
end
