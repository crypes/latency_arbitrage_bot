defmodule LatencyArbitrageBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :latency_arbitrage_bot,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :inets, :ssl],
      mod: {LatencyArbitrageBot.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:decimal, "~> 2.0"},
      {:websockex, "~> 0.4.3"},
      {:uuid, "~> 1.1"},
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.6"},
    ]
  end
end
