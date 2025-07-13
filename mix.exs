defmodule Pled.MixProject do
  use Mix.Project

  def project do
    [
      app: :pled,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Pled.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.4"},
      {:burrito, "~> 1.0"},
      {:slugify, "~> 1.3"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp releases do
    [
      pled: [
        steps: [:assemble, &Burrito.wrap/1],
        applications: [runtime_tools: :none],
        burrito: [
          targets: [
            macos: [os: :darwin, cpu: :x86_64],
            macos_arm: [os: :darwin, cpu: :aarch64]
          ]
        ]
      ]
    ]
  end

  defp aliases do
    [
      rebuild: [
        "escript.build",
        "cmd rm -rf src",
        "cmd rm -rf dist",
        "cmd ./pled pull",
        "cmd ./pled push"
      ]
    ]
  end
end
