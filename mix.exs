defmodule LatencyArbitrageBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :latency_arbitrage_bot,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {LatencyArbitrageBot.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:mint, "~> 1.4"},
      {:websockex, "~> 0.4.3"},
      {:req, "~> 0.4"},
      {:ethereumex, "~> 0.4"},
      {:ex_rlp, "~> 0.1"},
      {:poison, "~> 5.0"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:bandit, "~> 1.0"},
      {:hackney, "~> 1.18"},
      {:sweet_xml, "~> 0.7"},
      {:elixir_uuid, "~> 1.4"},
      {:decimal, "~> 2.0"},
      {:nimble_csv, "~> 1.2"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
