defmodule LatencyArbitrageBot.Data.EdgeEngine do
  @moduledoc "Evaluates cross-venue price edges in real-time and emits trade signals."
  use GenServer
  require Logger
  defstruct [thresholds: %{BTC: 0.008, ETH: 0.008}, window_ms: 500, signals: %{}, history: []]
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def on_price(pid, price_data), do: GenServer.cast(pid, {:price, price_data})
  def tick(pid), do: GenServer.cast(pid, :tick)
  def update_threshold(pid, symbol, threshold), do: GenServer.cast(pid, {:threshold, symbol, threshold})
  def get_history(pid), do: GenServer.call(pid, :history)
  def init(opts) do
    thresholds = opts |> Keyword.get(:thresholds, %{}) |> Map.merge(%{BTC: 0.008, ETH: 0.008}, fn _, _, v -> v end)
    {:ok, %{thresholds: thresholds, window_ms: Keyword.get(opts, :window_ms, 500), signals: %{}, history: []}}
  end
  def handle_cast({:price, price_data}, state), do: {:noreply, check_edge(price_data, state)}
  def handle_cast({:threshold, symbol, threshold}, state), do: {:noreply, put_in(state.thresholds[symbol], threshold)}
  def handle_call(:history, _from, state), do: {:reply, Enum.take(state.history, 100), state}
  defp check_edge(%{symbol: sym, polymarket: pp, reference: rp}, state) when is_number(pp) and is_number(rp) and rp > 0 do
    diff_pct = (pp - rp) / rp
    threshold = Map.get(state.thresholds, sym, 0.008)
    now = System.system_time(:millisecond)
    if abs(diff_pct) > threshold do
      entry = %{symbol: sym, poly: pp, ref: rp, diff_pct: diff_pct, ts: now}
      new_sigs = update_in(state.signals[sym], &[entry | List.wrap(&1)])
      %{state | signals: new_sigs}
    else
      %{state | signals: expire_signals(state.signals, sym, now, state.window_ms)}
    end
  end
  defp check_edge(_, state), do: state
  defp expire_signals(sigs, key, now, ms) do
    case Map.get(sigs, key, []) do
      [] -> sigs
      _ -> Map.put(sigs, key, Enum.filter(sigs[key], fn e -> now - e.ts <= ms end))
    end
  end
end