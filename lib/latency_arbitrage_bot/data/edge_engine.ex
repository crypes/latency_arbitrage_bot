defmodule LatencyArbitrageBot.Data.EdgeEngine do
  @moduledoc """
  Evaluates cross-venue price edges in real-time and emits trade signals.

  Each venue pair (e.g. Polymarket vs. Binance) produces an edge score:
    edge = polymarket_mid - reference_mid

  If |edge| > threshold AND within risk limits → emit trade signal
  to the execution pipeline.  Uses a sliding window to avoid over-trading
  on fleeting spikes.
  """
  use GenServer, restart: :permanent

  alias LatencyArbitrageBot.Data.{EdgeEngine, PriceOracle, RiskManager}
  alias LatencyArbitrageBot.Venues.Polymarket.Adapter, as: Poly

  @type edge_signal :: %{
          venue_a: atom,
          venue_b: atom,
          symbol: :BTC | :ETH,
          edge_pct: Decimal.t(),
          venue_a_price: Decimal.t(),
          venue_b_price: Decimal.t(),
          timestamp_ms: integer,
          confidence: float
        }

  defstruct [
    thresholds: %{BTC: 0.008, ETH: 0.008},  # 0.8% minimum edge
    window_ms: 500,                          # spike must persist 500ms
    signals: %{},
    history: []
  ]

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # ─── Public API ─────────────────────────────────────────────────────────────

  @doc "Called by PriceOracle subscriber on every consensus tick."
  @spec on_price(GenServer.server(), PriceOracle.price_data()) :: :ok
  def on_price(pid \\ __MODULE__, price_data) do
    GenServer.cast(pid, {:on_price, price_data})
  end

  @doc "Manually check and emit any pending signals (called on heartbeat timer)."
  @spec tick(GenServer.server()) :: :ok
  def tick(pid \\ __MODULE__), do: GenServer.cast(pid, :tick)

  @spec update_threshold(GenServer.server(), :BTC | :ETH, float()) :: :ok
  def update_threshold(pid \\ __MODULE__, symbol, threshold) do
    GenServer.cast(pid, {:update_threshold, symbol, threshold})
  end

  # ─── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    thresholds = Keyword.get(opts, :thresholds, %{BTC: 0.008, ETH: 0.008})
    PriceOracle.subscribe(PriceOracle, self(), :BTC)
    PriceOracle.subscribe(PriceOracle, self(), :ETH)
    schedule_tick(200)  # heartbeat every 200ms
    {:ok, %EdgeEngine{thresholds: thresholds}}
  end

  @impl true
  def handle_cast({:on_price, price_data}, state) do
    new_state = check_edge(price_data, state)
    {:noreply, new_state}
  end

  def handle_cast(:tick, state) do
    # Emit any confirmed signals whose window has passed
    state = emit_ready_signals(state)
    schedule_tick(200)
    {:noreply, state}
  end

  def handle_cast({:update_threshold, symbol, threshold}, state) do
    new_thresholds = Map.put(state.thresholds, symbol, threshold)
    {:noreply, %{state | thresholds: new_thresholds}}
  end

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp schedule_tick(ms), do: Process.send_after(self(), :tick, ms)

  defp check_edge(%{symbol: sym} = price_data, state) do
    # Get current Polymarket price (populated by venue adapter)
    poly_price = get_polymarket_price(sym)
    if poly_price do
      edge_pct = calculate_edge(poly_price, price_data.mid)
      threshold = Map.get(state.thresholds, sym, 0.008)
      if abs(edge_pct) > threshold do
        record_signal(sym, edge_pct, poly_price, price_data, state)
      else
        state
      end
    else
      state
    end
  end

  defp get_polymarket_price(:BTC), do: :persistent_term.get(:poly_btc_mid, nil)
  defp get_polymarket_price(:ETH), do: :persistent_term.get(:poly_eth_mid, nil)

  defp calculate_edge(poly_mid, ref_mid) do
    Decimal.to_float(Decimal.sub(poly_mid, ref_mid))
    |> then(fn diff -> diff / Decimal.to_float(ref_mid) end)
  end

  defp record_signal(sym, edge_pct, poly_price, ref_price, state) do
    signal = %{
      symbol: sym,
      edge_pct: edge_pct,
      poly_price: poly_price,
      ref_price: ref_price.mid,
      timestamp_ms: System.system_time(:millisecond),
      window_start: System.system_time(:millisecond)
    }
    # Store in history (keep last 100)
    history = [signal | state.history] |> Enum.take(100)
    %{state | history: history}
  end

  defp emit_ready_signals(state) do
    now = System.system_time(:millisecond)
    {ready, pending} = Enum.split_with(state.history, fn s ->
      now - s.window_start >= state.window_ms
    end)
    for signal <- ready do
      RiskManager.evaluate(signal)
    end
    %{state | history: pending}
  end
end
