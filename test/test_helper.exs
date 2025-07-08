# Load environment variables from .env.exs if it exists
env_file = Path.join(__DIR__, "../.env.exs")
if File.exists?(env_file) do
  Code.eval_file(env_file)
end

ExUnit.start()
