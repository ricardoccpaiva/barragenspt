defmodule Barragenspt.MixProject do
  use Mix.Project

  def project do
    [
      app: :barragenspt,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Barragenspt.Application, []},
      extra_applications: [:logger, :runtime_tools, :httpoison, :scrivener, :xmerl, :bugsnag]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.7"},
      {:nimble_csv, "~> 1.2.0"},
      {:oban, "~> 2.20"},
      {:oban_web, "~> 2.11"},
      {:httpoison, "~> 1.8"},
      {:floki, "~> 0.36"},
      {:geocalc, "~> 0.8"},
      {:briefly, "~> 0.3"},
      {:uuid, "~> 1.1"},
      {:timex, "~> 3.0"},
      {:nebulex, "~> 2.2"},
      {:decorator, "~> 1.4"},
      {:scrivener_ecto, "~> 2.7"},
      {:prom_ex, "~> 1.9.0"},
      {:plug_canonical_host, "~> 2.0"},
      {:tesla, "~> 1.4"},
      {:codepagex, "~> 0.1.6"},
      {:recase, "~> 0.5"},
      {:opentelemetry_api, "~> 1.0"},
      {:opentelemetry, "~> 1.0"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:opentelemetry_phoenix, "~> 1.0"},
      {:opentelemetry_ecto, "~> 1.0"},
      {:opentelemetry_oban, "~> 1.0"},
      {:opentelemetry_liveview, "~> 1.0.0-rc"},
      {:xxhash, "~> 0.3.1"},
      {:vega_lite, "~> 0.1.8"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:sweet_xml, "~> 0.7.4"},
      {:mogrify, "~> 0.9.3"},
      {:opentelemetry_logger_metadata, "~> 0.1.0"},
      {:bugsnag, "~> 3.0.2"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
