defmodule LatencyArbitrageBot.Venues.Polymarket.Adapter do
  @moduledoc """
  Polymarket venue adapter — subscribes to the CLOB WebSocket, places
  orders via the CLOB REST API, and writes a :poly_btc_mid / :poly_eth_mid
  entry into :persistent_term so the EdgeEngine can read it lock-free.

  Auth: EIP-712 signature over the user's Polyg了一层 wallet private key.
  Network: Polygon PoS (RPC: https://polygon-rpc.com)
  Fee: Dynamic taker up to 1.80% (see config.exs)
  """
  use GenServer, restart: :permanent

  alias LatencyArbitrageBot.Venues.Polymarket.Signer

  @clob_ws "wss://clob.polymarket.com/ws"
  @clob_rest "https://clob.polymarket.com"

  # Market condition IDs (BTC > $95k / ETH > $3.5k by EOD etc.)
  @btc_condition_id "0x0000000000000000000000000000000000000000"  # REPLACE with real
  @eth_condition_id "0x0000000000000000000000000000000000000000"  # REPLACE with real

  defstruct [:ws_conn, :orders, :pending_orders: %{}, connected?: false]

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # ─── Public API ─────────────────────────────────────────────────────────────

  @doc "Place a YES order on Polymarket CLOB."
  @spec place_order(GenServer.server(), :BTC | :ETH, :yes | :no, Decimal.t(), Decimal.t()) ::
          {:ok, order_id :: String.t()} | {:error, term()}
  def place_order(pid \\ __MODULE__, symbol, side, price, notional) do
    GenServer.call(pid, {:place_order, symbol, side, price, notional}, 10_000)
  end

  @doc "Cancel an outstanding order by ID."
  @spec cancel_order(GenServer.server(), String.t()) :: :ok | {:error, term()}
  def cancel_order(pid \\ __MODULE__, order_id) do
    GenServer.call(pid, {:cancel_order, order_id}, 5_000)
  end

  @doc "Get best bid/ask for a symbol from the local order book cache."
  @spec best_price(GenServer.server(), :BTC | :ETH) :: {Decimal.t(), Decimal.t()} | nil
  def best_price(pid \\ __MODULE__, symbol) do
    GenServer.call(pid, {:best_price, symbol})
  end

  # ─── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    schedule_connect(0)
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_info(:connect, state) do
    case connect_websocket() do
      {:ok, conn} ->
        :ok = subscribe_to_markets(conn)
        {:noreply, %{state | ws_conn: conn, connected?: true}}
      {:error, reason} ->
        schedule_connect(5_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:place_order, symbol, side, price, notional}, _from, state) do
    outcome <- if side == :yes, do: "Yes", else: "No"
    cond_id = if symbol == :BTC, do: @btc_condition_id, else: @eth_condition_id

    payload = %{
      "conditionId" => cond_id,
      "outcome" => outcome,
      "side" => String.upcase(Atom.to_string(side)),
      "price" => Decimal.to_string(price),
      "size" => Decimal.to_string(notional)
    }

    case Signer.sign_payload(payload) do
      {:ok, sig} ->
        case post_order(Map.merge(payload, %{"signature" => sig})) do
          {:ok, order_id} ->
            new_pending = Map.put(state.pending_orders, order_id, %{symbol: symbol, side: side})
            {:reply, {:ok, order_id}, %{state | pending_orders: new_pending}}
          error ->
            {:reply, error, state}
        end
      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  def handle_call({:cancel_order, order_id}, _from, state) do
    case delete_order(order_id) do
      :ok -> {:reply, :ok, %{state | pending_orders: Map.delete(state.pending_orders, order_id)}}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:best_price, symbol}, _from, state) do
    result = get_best_price(state, symbol)
    {:reply, result, state}
  end

  # ─── WebSocket message handler ───────────────────────────────────────────────

  def handle_info({:websocket, _conn, msg}, state) do
    new_state = process_ws_message(msg, state)
    {:noreply, new_state}
  end

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp schedule_connect(ms), do: Process.send_after(self(), :connect, ms)

  defp connect_websocket do
    {:ok, conn} = :websocket_client.start_link(@clob_ws, __MODULE__, [])
    {:ok, conn}
  rescue
    _ -> {:error, :connection_failed}
  end

  defp subscribe_to_markets(conn) do
    msg = Jason.encode!(%{
      type: "subscribe",
      channel: "orderbook",
      markets: [@btc_condition_id, @eth_condition_id]
    })
    :websocket_client.send(conn, {:text, msg})
  end

  defp process_ws_message(raw, state) do
    case Jason.decode(raw) do
      {:ok, %{"type" => "orderbook", "conditionId" => cid, "bids" => bids, "asks" => asks}} ->
        sym = if cid == @btc_condition_id, do: :BTC, else: :ETH
        {best_bid, best_ask} = compute_best_price(bids, asks)
        mid = if best_bid && best_ask,
                 do: Decimal.add(best_bid, best_ask) |> Decimal.div(2),
                 else: nil
        if mid, do: :persistent_term.put(:"poly_#{sym |> Atom.to_string() |> String.downcase()}_mid", mid)
        state
      _ ->
        state
    end
  end

  defp compute_best_price(bids, asks) do
    best_bid = bids |> List.first() |> then(fn b -> b && Decimal.new(b["price"]) end)
    best_ask = asks |> List.first() |> then(fn a -> a && Decimal.new(a["price"]) end)
    {best_bid, best_ask}
  end

  defp get_best_price(state, symbol) do
    # Read from persistent_term (written by WS handler)
    field = :"poly_#{symbol |> Atom.to_string() |> String.downcase()}_mid"
    mid = :persistent_term.get(field, nil)
    if mid, do: {mid, mid}, else: nil
  end

  defp post_order(payload) do
    case Req.post("#{@clob_rest}/orders", json: payload) do
      {:ok, %{status: 200, body: %{"success" => true, "order" => %{"orderId" => id}}}} ->
        {:ok, id}
      {:ok, %{body: %{"error" => err}}} ->
        {:error, err}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_order(order_id) do
    case Req.delete("#{@clob_rest}/orders/#{order_id}") do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{body: %{"error" => err}}} -> {:error, err}
      {:error, reason} -> {:error, reason}
    end
  end
end
