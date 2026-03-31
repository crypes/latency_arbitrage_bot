defmodule LatencyArbitrageBot.Support.Telemetry do
  @moduledoc "Lightweight in-process telemetry — emits events for edge, latency, P&L."
  use GenServer, restart: :permanent

  defstruct [:metrics]

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # ─── Emit macros (called from anywhere) ────────────────────────────────────

  defmacro emit(event, measurements, metadata \\ quote do %{} end) do
    quote do
      :telemetry.execute(
        [__MODULE__, unquote(event)],
        unquote(measurements),
        unquote(metadata)
      )
    end
  end

  # Convenience wrappers
  def emit_edge(symbol, edge_pct, latency_ms) do
    :telemetry.execute([:latency_arbitrage_bot, :edge, :evaluated],
      %{edge_pct: edge_pct, latency_ms: latency_ms},
      %{symbol: symbol}
    )
  end

  def emit_trade(symbol, notional, result) do
    :telemetry.execute([:latency_arbitrage_bot, :trade, result],
      %{notional: notional},
      %{symbol: symbol}
    )
  end

  @impl true
  def init(_) do
    # Attach handlers for metrics export
    :telemetry.attach_many(
      "telemetry-exporter",
      [[:latency_arbitrage_bot, :edge, :_],
       [:latency_arbitrage_bot, :trade, :_]],
      &__MODULE__.handle_event/4,
      []
    )
    {:ok, %{}}
  end

  @impl true
  def handle_event(_event, measurements, metadata, _config) do
    # Log to console in dev; in prod ship to Loki / Datadog
    Logger.info("[TELEMETRY] #{inspect(measurements)} #{inspect(metadata)}")
  end
end
