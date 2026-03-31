defmodule LatencyArbitrageBot.Application do
  @moduledoc """
  OTP Application for the Latency Arbitrage Bot.
  Starts all supervision trees: venue adapters, data pipeline, risk engine.
  """
  use Application

  def start(_type, _args) do
    children = [
      # ── Core data pipeline ──────────────────────────────────────────────
      LatencyArbitrageBot.Support.Telemetry,
      LatencyArbitrageBot.Data.PriceOracle,
      LatencyArbitrageBot.Data.EdgeEngine,
      LatencyArbitrageBot.Data.RiskManager,

      # ── Venue adapters ─────────────────────────────────────────────────
      # Polymarket: WebSocket (CLOB) + REST (orders)
      LatencyArbitrageBot.Venues.Polymarket.Adapter,

      # Kalshi: REST (orders + market data) + WebSocket (live orderbook)
      # Start only if :kalshi_api_key is configured
      {LatencyArbitrageBot.Venues.Kalshi.Adapter, []},

      # ── HTTP health / metrics endpoint (Plug) ──────────────────────────
      {Plug.Cowboy, scheme: :http, plug: LatencyArbitrageBot.Support.Endpoint, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: LatencyArbitrageBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
