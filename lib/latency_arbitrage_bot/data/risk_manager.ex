defmodule LatencyArbitrageBot.Data.RiskManager do
  @moduledoc """
  Global position and exposure limits.

  Evaluates each signal from the EdgeEngine against:
  - Max notional exposure per symbol
  - Max total notional across all positions
  - Max trades per minute (rate limit guard)
  - Daily loss limit (circuit breaker)

  Only emits to execution if ALL checks pass.
  """
  use GenServer, restart: :permanent

  alias LatencyArbitrageBot.Data.RiskManager
  alias LatencyArbitrageBot.Venues.Polymarket.Adapter, as: Poly

  @type position :: %{symbol: atom, notional: Decimal.t(), entry_price: Decimal.t()}
  @type signal :: map()

  defstruct positions: %{},
            trades_today: 0,
            pnl_today: Decimal.new(0),
            trade_timestamps: [],
            config: %{
              max_notional_per_symbol: Decimal.new(50),     # $50 per leg
              max_total_notional: Decimal.new(200),         # $200 total
              max_trades_per_minute: 10,
              daily_loss_limit: Decimal.new(-20),           # stop if P&L < -$20
              max_position_age_ms: 15 * 60 * 1000          # 15 min max hold
            }

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # ─── Public API ─────────────────────────────────────────────────────────────

  @doc "Called by EdgeEngine to ask: should this signal be executed?"
  @spec evaluate(GenServer.server(), signal()) :: :ok | :rejected
  def evaluate(pid \\ __MODULE__, signal) do
    GenServer.call(pid, {:evaluate, signal}, 5_000)
  end

  @doc "Called by execution pipeline after a trade fills (or fails)."
  @spec record_trade(GenServer.server(), signal(), :filled | :rejected | :failed) :: :ok
  def record_trade(pid \\ __MODULE__, signal, result) do
    GenServer.cast(pid, {:record_trade, signal, result})
  end

  @doc "Read current positions and P&L snapshot."
  @spec status(GenServer.server()) :: map()
  def status(pid \\ __MODULE__) do
    GenServer.call(pid, :status)
  end

  @doc "Reset daily counters (called at UTC midnight)."
  @spec reset_daily(GenServer.server()) :: :ok
  def reset_daily(pid \\ __MODULE__) do
    GenServer.cast(pid, :reset_daily)
  end

  # ─── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    config = Keyword.get(opts, :config, %{}) |> Map.merge(default_config())
    {:ok, %RiskManager{config: config}}
  end

  @impl true
  def handle_call({:evaluate, signal}, _from, state) do
    result = run_checks(signal, state)
    {:reply, result, state}
  end

  def handle_call(:status, _from, state) do
    {:reply, %{
      positions: state.positions,
      trades_today: state.trades_today,
      pnl_today: state.pnl_today,
      config: state.config
    }, state}
  end

  def handle_cast({:record_trade, _signal, :filled}, state) do
    {:noreply, %{state |
      trades_today: state.trades_today + 1,
      trade_timestamps: [System.system_time(:millisecond) | state.trade_timestamps]
    }}
  end

  def handle_cast({:record_trade, _signal, _}, state) do
    {:noreply, state}
  end

  def handle_cast(:reset_daily, state) do
    {:noreply, %{state | trades_today: 0, pnl_today: Decimal.new(0), trade_timestamps: []}}
  end

  # ─── Internal ─────────────────────────────────────────────────────────────────

  defp default_config do
    %{
      max_notional_per_symbol: Decimal.new(50),
      max_total_notional: Decimal.new(200),
      max_trades_per_minute: 10,
      daily_loss_limit: Decimal.new(-20),
      max_position_age_ms: 15 * 60 * 1000
    }
  end

  defp run_checks(signal, state) do
    with :ok <- check_rate_limit(state),
         :ok <- check_daily_loss(state),
         :ok <- check_total_notional(signal, state),
         :ok <- check_symbol_notional(signal, state),
         do: :ok
  end

  defp check_rate_limit(state) do
    now = System.system_time(:millisecond)
    last_minute = now - 60_000
    recent = Enum.count(state.trade_timestamps, &(&1 > last_minute))
    if recent < state.config.max_trades_per_minute, do: :ok, else: :rate_limited
  end

  defp check_daily_loss(state) do
    if Decimal.compare(state.pnl_today, state.config.daily_loss_limit) == :gt,
      do: :ok, else: :daily_loss_limit_reached
  end

  defp check_total_notional(signal, state) do
    pos_value = signal |> Map.get(:notional, Decimal.new(25))
    total = state.positions |> Map.values() |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    if Decimal.add(total, pos_value) |> Decimal.compare(state.config.max_total_notional) == :lt,
      do: :ok, else: :total_notional_exceeded
  end

  defp check_symbol_notional(signal, state) do
    current = Map.get(state.positions, signal.symbol, Decimal.new(0))
    if Decimal.add(current, Decimal.new(25))
       |> Decimal.compare(state.config.max_notional_per_symbol) == :lt,
      do: :ok, else: :symbol_notional_exceeded
  end
end
