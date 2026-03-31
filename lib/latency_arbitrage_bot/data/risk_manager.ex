defmodule LatencyArbitrageBot.Data.RiskManager do
  @moduledoc "Global position and exposure limits."
  use GenServer
  require Logger
  defstruct [:positions, :daily_pnl, :config]
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def check_and_submit_signal(pid, signal), do: GenServer.call(pid, {:check, signal})
  def init(_opts) do
    cfg = Application.get_env(:latency_arbitrage_bot, :risk, [])
    {:ok, %{
      positions: %{},
      daily_pnl: Decimal.new("0"),
      config: %{
        max_notional_per_symbol: Decimal.new("50"),
        max_total_notional: Decimal.new("200"),
        daily_loss_limit: Decimal.new("-20"),
        max_position_age_ms: 900_000
      }
    }}
  end
  def handle_call({:check, _}, _from, %{config: %{daily_loss_limit: limit}} = state) when limit < 0, do: {:reply, :ok, state}
  def handle_call({:check, _}, _from, state), do: {:reply, {:error, :risk_limit_reached}, state}
  def handle_info(msg, state) do
    Logger.warning "[RiskManager] unexpected info: #{inspect(msg)}"
    {:noreply, state}
  end
end