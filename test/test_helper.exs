# Load environment variables from .env.exs if it exists
env_file = ".env.exs"

if File.exists?(env_file) do
  Code.eval_file(env_file)
end

ExUnit.start()
