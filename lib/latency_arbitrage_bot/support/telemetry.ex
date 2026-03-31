defmodule LatencyArbitrageBot.Support.Telemetry do
  @moduledoc "Lightweight in-process telemetry events."
  use GenServer, restart: :permanent
  defstruct [:metrics]
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
  @impl true
  def init(_), do: {:ok, %{metrics: %{}}}
  @impl true
  def handle_cast({:edge, data}, state) do
    key = {:edge, data.symbol, data.venue_a, data.venue_b}
    metrics = Map.update(state.metrics, key, 1, & &1)
    {:noreply, %{state | metrics: metrics}}
  end
  @impl true
  def handle_cast({:latency, venue, ms}, state) do
    metrics = Map.update(state.metrics, {:latency, venue}, [ms], &[ms | &1])
    {:noreply, %{state | metrics: metrics}}
  end
  @impl true
  def handle_cast({:signal, dir, pct}, state) do
    metrics = Map.update(state.metrics, {:signal, dir}, [pct], &[pct | &1])
    {:noreply, %{state | metrics: metrics}}
  end
  def metrics(pid), do: GenServer.call(pid, :metrics)
  @impl true
  def handle_call(:metrics, _from, state), do: {:reply, state.metrics, state}
end