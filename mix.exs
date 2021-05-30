defmodule Elisnake.MixProject do
  use Mix.Project

  @source_url "https://github.com/thiagoesteves/elisnake"

  def project do
    [
      app: :elisnake,
      elixirc_options: elixirc_options(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_options: erlc_options(Mix.env()),
      version: "0.1.0",
      elixir: "~> 1.11",
      name: "elisnake",
      description: description(),
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Do not start application during the tests
  defp aliases do
    [
      test: ["test --no-start"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :gproc, :runtime_tools],
      mod: {Elisnake.Application, []}
    ]
  end

  defp description do
    "Snake Game implemented in Elixir"
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gproc, git: "git://github.com/uwiger/gproc", tag: "0.9.0"},
      {:plug_cowboy, "~> 2.0"},
      {:jason, "~> 1.2"},
      {:distillery, "~> 2.1.1"},
      {:logger_file_backend, "~> 0.0.11"},
      # For dev only
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      # For test only
      {:excoveralls, "~> 0.13", only: :test},
      {:gun, "~> 2.0.0-rc.2", only: [:test]},
      {:httpoison, "~> 1.8", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp elixirc_paths(_), do: ["lib"]

  defp elixirc_options(:prod) do
    [debug_info: false, all_warnings: true, warnings_as_errors: true]
  end

  defp elixirc_options(_) do
    [debug_info: true, all_warnings: true, warnings_as_errors: true]
  end

  defp erlc_options(:prod) do
    [:warnings_as_errors]
  end

  defp erlc_options(_) do
    [:warnings_as_errors, :debug_info]
  end
end
