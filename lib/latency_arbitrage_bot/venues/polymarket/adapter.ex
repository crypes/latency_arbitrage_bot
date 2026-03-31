defmodule LatencyArbitrageBot.Venues.Polymarket.Adapter do
  @moduledoc "Polymarket CLOB venue adapter. Connects via WebSocket to wss://clob.polymarket.com, places orders signed with EIP-712."
  use GenServer, restart: :permanent
  require Logger
  alias LatencyArbitrageBot.Venues.Polymarket.Signer
  def start_link(opts) do
    case GenServer.start_link(__MODULE__, opts, name: __MODULE__) do
      {:ok, pid} -> {:ok, pid}
      err -> err
    end
  end
  @ws_url "wss://clob.polymarket.com"
  defstruct [:ws_conn, :orders, :pending_orders, :connected?]
  @impl true
  def init(opts) do
    {:ok, %__MODULE__{ws_conn: nil, orders: %{}, pending_orders: %{}, connected?: false}}
  end
  @impl true
  def handle_cast({:place_order, condition_id, side, price, size, reply_to}, state) do
    order = build_order(condition_id, side, price, size, state)
    signed = Signer.sign_order(order)
    msg = Jason.encode!(%{type: "order", order: signed})
    :ok = :websocket_client.send(state.ws_conn, {:text, msg})
    pending = Map.put(state.pending_orders, order["orderID"], {reply_to, order})
    {:noreply, %{state | pending_orders: pending}}
  end
  @impl true
  def handle_info({:websocket, _conn, {:text, raw}}, state) do
    case Jason.decode(raw) do
      {:ok, %{"type" => "order_ack", "order" => order, "success" => true}} ->
        {{reply_to, _order}, pending} = Map.pop(state.pending_orders, order["orderID"])
        send(reply_to, {:ok, order})
        {:noreply, %{state | pending_orders: pending}}
      {:ok, %{"type" => "error", "message" => msg}} ->
        Logger.error("[Polymarket] error: \#{msg}")
        {:noreply, state}
      _ -> {:noreply, state}
    end
  end
  @impl true
  def handle_info({:websocket_closed, _, _}, state) do
    Logger.warning("[Polymarket] WebSocket closed, reconnecting...")
    {:noreply, connect(%{state | connected?: false}, [])}
  end
  defp build_order(condition_id, side, price, size, state) do
    %{
      "conditionID" => condition_id,
      "side" => side,
      "price" => price,
      "size" => size,
      "orderID" => :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      "address" => Application.get_env(:latency_arbitrage_bot, :polymarket)[:address]
    }
  end
  defp start_websocket(state) do
    case :websocket_client.start_link(self(), @ws_url, __MODULE__) do
      {:ok, conn} -> {:ok, %{state | ws_conn: conn, connected?: true}}
      {:error, r} -> Logger.error("[Polymarket] connect failed: \#{inspect(r)}"); state
    end
  end
end
