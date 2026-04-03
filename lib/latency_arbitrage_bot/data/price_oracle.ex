defmodule LatencyArbitrageBot.Data.PriceOracle do
  @moduledoc "Central price oracle. Broadcasts consensus price ticks to all subscribers."
  use GenServer
  require Logger

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def subscribe, do: GenServer.call(__MODULE__, :subscribe)
  def latest, do: GenServer.call(__MODULE__, :latest)

  @doc "Called by venue adapters when a market price updates."
  def on_market_update(venue, data) do
    GenServer.cast(__MODULE__, {:market_update, venue, data})
  end

  def init(_opts), do: {:ok, %{prices: %{}, peers: %{}}}

  def handle_call(:subscribe, {pid, _} = _from, state) do
    ref = Process.monitor(pid)
    {:reply, :ok, put_in(state.peers[pid], ref)}
  end

  def handle_call(:latest, _from, state), do: {:reply, state.prices, state}

  def handle_cast({:market_update, venue, data}, state) do
    prices = Map.put(state.prices, venue, data)
    Enum.each(state.peers, fn {pid, _} -> send(pid, {:price_update, venue, data}) end)
    {:noreply, %{state | prices: prices}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | peers: Map.delete(state.peers, pid)}}
  end
end
