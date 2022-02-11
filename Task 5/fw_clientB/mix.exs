defmodule FWClientRobotB.MixProject do
  use Mix.Project

  def project do
    [
      app: :task_4c_client_robotb,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: FWClientRobotB]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, only: :dev, runtime: false},
      {:phoenix_client, "~> 0.3"},
      # {:circuits_gpio, "~> 0.4"},
      # {:pigpiox, "~> 0.1.2"}
      {:jason, "~> 1.1"}

      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
