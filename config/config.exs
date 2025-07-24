import Config

config :pled, compile_env: Mix.env(), version: Mix.Project.config()[:version]
