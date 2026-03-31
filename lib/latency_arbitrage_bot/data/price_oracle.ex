defmodule LatencyArbitrageBot.Data.PriceOracle do
  @moduledoc "Central price oracle. Broadcasts consensus price ticks to all subscribers."
  use GenServer
  require Logger
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def subscribe, do: GenServer.call(__MODULE__, :subscribe)
  def latest, do: GenServer.call(__MODULE__, :latest)
  def init(_opts), do: {:ok, %{prices: %{}, peers: %{}}}
  def handle_call(:subscribe, {pid, _} = _from, state) do
    ref = Process.monitor(pid)
    {:reply, :ok, put_in(state.peers[pid], ref)}
  end
  def handle_call(:latest, _from, state), do: {:reply, state.prices, state}
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | peers: Map.delete(state.peers, pid)}}
  end
end