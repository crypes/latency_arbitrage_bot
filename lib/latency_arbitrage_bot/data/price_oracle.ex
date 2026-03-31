defmodule LatencyArbitrageBot.Data.PriceOracle do
  @moduledoc """
  Central price oracle — ingests price feeds from multiple upstream sources
  (Binance, Coinbase, Kraken) and broadcasts normalised BTC/ETH ticks to
  all subscribed venue adapters and the edge engine.

  Acts as a GenServer so all consumers get the SAME price snapshot
  with sub-millisecond in-process delivery (no network round-trips).
  """
  use GenServer, restart: :permanent

  alias LatencyArbitrageBot.Data.PriceOracle

  @type symbol :: :BTC | :ETH
  @type price_data :: %{
          symbol: symbol,
          bid: Decimal.t(),
          ask: Decimal.t(),
          mid: Decimal.t(),
          source: atom,
          timestamp_ms: integer
        }

  defstruct [
    :btc_binance, :btc_coinbase, :btc_kraken,
    :eth_binance, :eth_coinbase, :eth_kraken,
    :btc_consensus, :eth_consensus,
    subscribers: %{}
  ]

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # ─── Public API ────────────────────────────────────────────────────────────

  @doc "Called by a venue adapter WebSocket handler when it receives a trade tick"
  @spec ingest(GenServer.server(), atom, price_data) :: :ok
  def ingest(pid \\ __MODULE__, source, data) do
    GenServer.cast(pid, {:ingest, source, data})
  end

  @doc "Subscribe to consensus price updates.  Messages are {:"<> "price_update, price_data}."
  @spec subscribe(GenServer.server(), pid, symbol) :: :ok
  def subscribe(pid \\ __MODULE__, client, symbol) do
    GenServer.cast(pid, {:subscribe, client, symbol})
  end

  @doc "Unsubscribe a client from price updates."
  @spec unsubscribe(GenServer.server(), pid) :: :ok
  def unsubscribe(pid \\ __MODULE__, client) do
    GenServer.cast(pid, {:unsubscribe, client})
  end

  @doc "Read the current consensus price for a symbol."
  @spec get_price(GenServer.server(), symbol) :: price_data | nil
  def get_price(pid \\ __MODULE__, symbol) do
    GenServer.call(pid, {:get_price, symbol})
  end

  # ─── GenServer callbacks ───────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    state = %PriceOracle{}
    # Start WebSocket connections to Binance and Coinbase in separate processes
    spawn_venue_feeds()
    {:ok, state}
  end

  @impl true
  def handle_call({:get_price, symbol}, _from, state) do
    price = Map.get(state, :"#{symbol |> Atom.to_string() |> String.downcase()}_consensus")
    {:reply, price, state}
  end

  @impl true
  def handle_cast({:ingest, source, data}, state) do
    new_state = store_tick(state, source, data)
    maybe_broadcast(new_state, data.symbol)
    {:noreply, new_state}
  end

  def handle_cast({:subscribe, client, symbol}, state) do
    subs = update_in(state.subscribers, [Access.key(symbol, %{})], &Map.put(&1, client, true))
    {:noreply, subs}
  end

  def handle_cast({:unsubscribe, client}, state) do
    subs = Map.new()
    {:noreply, %{state | subscribers: subs}}
  end

  # ─── Internal ─────────────────────────────────────────────────────────────

  defp spawn_venue_feeds do
    # Binance WebSocket trade stream (BTC & ETH)
    Task.Supervisor.start_child(
      LatencyArbitrageBot.TaskSupervisor,
      fn -> BinanceWebSocketFeed.run() end,
      restart: :permanent
    )
    # Coinbase Advanced Trade WebSocket
    Task.Supervisor.start_child(
      LatencyArbitrageBot.TaskSupervisor,
      fn -> CoinbaseWebSocketFeed.run() end,
      restart: :permanent
    )
  end

  defp store_tick(state, source, %{symbol: sym} = data) do
    field = "#{sym |> Atom.to_string() |> String.downcase()}_#{source}" |> String.to_atom()
    Map.put(state, field, data)
  end

  defp maybe_broadcast(state, symbol) do
    ticks = collect_ticks(state, symbol)
    if length(ticks) >= 2 do
      consensus = compute_consensus(ticks)
      broadcast(symbol, consensus, state.subscribers)
    end
  end

  defp collect_ticks(state, symbol) do
    sym_str = symbol |> Atom.to_string() |> String.downcase()
    [:binance, :coinbase, :kraken]
    |> Enum.map(fn src -> Map.get(state, :"#{sym_str}_#{src}") end)
    |> Enum.reject(&is_nil/1)
  end

  defp compute_consensus(ticks) do
    # VWAP-style consensus: weight by inverse distance from median
    mids = Enum.map(ticks, & &1.mid)
    median = mids |> Enum.sort() |> then(fn m -> Enum.at(m, div(length(m), 2)) end)
    valid = Enum.reject(ticks, &(Decimal.compare(&1.mid, median) == :eq))
    case valid do
      [] -> List.first(ticks)
      [single] -> single
      filtered -> weighted_average(filtered, median)
    end
  end

  defp weighted_average(ticks, _median) do
    total_vol = ticks |> Enum.map(&Decimal.to_float(&1.mid)) |> Enum.sum()
    weighted = ticks
               |> Enum.map(&{Decimal.to_float(&1.mid), 1.0})
               |> Enum.zip()
               |> Enum.map(fn {v, _w} -> v end)
    mid = if total_vol > 0, do: Enum.sum(Enum.map(ticks, fn t -> Decimal.to_float(t.mid) / length(ticks) end)), else: 0
    %{List.first(ticks) | mid: Decimal.new(Float.to_string(mid)), source: :consensus}
  end

  defp broadcast(symbol, data, subscribers) do
    msg = {:price_update, data}
    for {pid, _} <- Map.get(subscribers, symbol, %{}), do: send(pid, msg)
  end
end

# ─── Binance WebSocket Feed ─────────────────────────────────────────────────
defmodule BinanceWebSocketFeed do
  @binance_ws "wss://stream.binance.com:9443/ws/!miniTicker@arr"
  @symbols %{:"BTCUSDT" => :BTC, :"ETHUSDT" => :ETH}

  def run() do
    HTTPoison.get!(@binance_ws, [], recv_timeout: :infinity, stream_to: self())

    receive do
      msg -> process_message(msg)
    end
  end

  defp process_message(%HTTPoison.AsyncChunk{id: _, value: raw}) do
    case Jason.decode(raw) do
      {:ok, ticks} ->
        for tick <- ticks, sym = @symbols[String.to_atom(tick["s"])], do: emit_tick(sym, tick)
      _ -> :ok
    end
    run()
  end

  defp emit_tick(sym, tick) do
    bid = Decimal.new(tick["b"])
    ask = Decimal.new(tick["a"])
    LatencyArbitrageBot.Data.PriceOracle.ingest(:binance, %{
      symbol: sym,
      bid: bid, ask: ask,
      mid: Decimal.add(bid, ask) |> Decimal.div(2),
      source: :binance,
      timestamp_ms: System.system_time(:millisecond)
    })
  end
end

# ─── Coinbase Advanced Trade WebSocket Feed ──────────────────────────────────
defmodule CoinbaseWebSocketFeed do
  @coinbase_ws "wss://advanced-trade-ws.coinbase.com"
  @product_ids ["BTC-USD", "ETH-USD"]

  def run() do
    # WebSocket connection via Mint (low-level, no extra deps)
    {:ok, conn} = Mint.HTTP.connect(:client, "advanced-trade-ws.coinbase.com", 443, mode: :passive)
    :ok = Mint.WebSocket.send_binary(conn, subscribe_msg())
    {:ok, conn, _ref} = Mint.WebSocket.ws_handshake(conn, "/")
    loop(conn)
  end

  defp subscribe_msg() do
    Jason.encode!(%{
      type: "subscribe",
      product_ids: @product_ids,
      channel: "market_trades"
    })
  end

  defp loop(conn) do
    {:ok, conn, messages} = Mint.WebSocket.recv(conn, 5000)
    for msg <- messages, do: process_message(msg)
    loop(conn)
  end

  defp process_message({:ws, _, data}) do
    case Jason.decode(data) do
      {:ok, %{"type" => "match", "product_id" => pid, "price" => p, "size" => _sz}} ->
        sym = if pid == "BTC-USD", do: :BTC, else: :ETH
        price = Decimal.new(p)
        LatencyArbitrageBot.Data.PriceOracle.ingest(:coinbase, %{
          symbol: sym,
          bid: price, ask: price,
          mid: price,
          source: :coinbase,
          timestamp_ms: System.system_time(:millisecond)
        })
      _ -> :ok
    end
  end
end
