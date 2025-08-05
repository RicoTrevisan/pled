defmodule Pled.Commands.Help do
  def run do
    logo()

    IO.puts("""

    Bubble.io Plugin Development Tool
    version #{Application.get_env(:pled, :version)}

    Usage:
      pled pull             Fetch plugin from Bubble.io and save to src/plugin.json
      pled push             Encodes and then upload plugin to Bubble.io
      pled encode           Prepares the files to upload. Compiles src/ files into dist/plugin.json
      pled upload <file>    Upload a file to Bubble.io CDN
      pled watch            Starts the server that watches the `src/` directory for changes and pushes it to Bubble.

    Required Environment Variables:
      PLUGIN_ID             The ID of the plugin to fetch
      COOKIE                Authentication cookie for Bubble.io
    """)

    :ok
  end

  def logo do
    IO.puts(~S(
        __________________________________________________________
       ___/\/\/\/\/\____/\/\________/\/\/\/\/\/\__/\/\/\/\/\_____
      ___/\/\____/\/\__/\/\________/\____________/\/\____/\/\___
     ___/\/\/\/\/\____/\/\________/\/\/\/\/\____/\/\____/\/\___
    ___/\/\__________/\/\________/\/\__________/\/\____/\/\___
   ___/\/\__________/\/\/\/\/\__/\/\/\/\/\/\__/\/\/\/\/\_____
  __________________________________________________________
        ))
  end
end
