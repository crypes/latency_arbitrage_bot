defmodule LatencyArbitrageBot.Application do
  @moduledoc """
  OTP Application for the Latency Arbitrage Bot.
  Starts all supervision trees: venue adapters, data pipeline, risk engine.
  """
  use Application

  def start(_type, _args) do
    children = [
      # Telemetry aggregator
      LatencyArbitrageBot.Support.Telemetry,
      # Price oracle — fan-out to all subscribed venues
      LatencyArbitrageBot.Data.PriceOracle,
      # Edge engine — heartbeat of the strategy
      LatencyArbitrageBot.Data.EdgeEngine,
      # Risk manager — global position and exposure limits
      LatencyArbitrageBot.Data.RiskManager,
      # Polymarket venue adapter (WebSocket + REST CLOB)
      {LatencyArbitrageBot.Venues.Polymarket.Adapter, []},
      # Venue supervisor registries
      LatencyArbitrageBot.Venues.Supervisor,
      # HTTP endpoint for health / metrics
      {Bandit, plug: LatencyArbitrageBot.Support.Endpoint, port: 4000}
    ]

    opts = [strategy: :one_for_one, name: LatencyArbitrageBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
