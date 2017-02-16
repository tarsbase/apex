defmodule Ello.Auth.Mixfile do
  use Mix.Project

  def project do
    [app: :ello_auth,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def elixirc_paths(:test), do: ["lib", "test/support"]
  def elixirc_paths(_),     do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ello_core, in_umbrella: true},

      {:joken, "~> 1.3.0"},
      {:poison, "~> 2.0"},
      {:plug, "~> 1.3.0"},
    ]
  end
end