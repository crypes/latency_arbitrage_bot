defmodule LatencyArbitrageBot.Venues.Polymarket.Adapter do
  @moduledoc "Polymarket CLOB WebSocket adapter."
  use GenServer
  require Logger
  alias LatencyArbitrageBot.Venues.Polymarket.Signer
  alias LatencyArbitrageBot.Data.PriceOracle

  @ws_url "wss://ws-subscriptions.clob.polymarket.com/stage"

  defstruct [:ws_conn, :address, :signer, :pending_orders, :connected?]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok, state} = connect(opts)
    {:ok, state}
  rescue
    e -> {:stop, {:init_failed, e}}
  end

  def handle_info({:websocket_closed, _, _}, state) do
    Logger.warning("[Polymarket] WebSocket closed, reconnecting...")
    {:ok, new_state} = connect_reconnect(state)
    {:noreply, %{new_state | connected?: true}}
  end

  def handle_info({:binary, msg}, state) do
    case Jason.decode(msg) do
      {:ok, %{"type" => "order_ack", "order" => order, "success" => true}} ->
        {{reply_to, _order}, pending} = Map.pop(state.pending_orders, order["orderID"])
        send(reply_to, {:ok, order})
        {:noreply, %{state | pending_orders: pending}}
      {:ok, %{"type" => "error", "message" => msg}} ->
        Logger.error("[Polymarket] error: #{msg}")
        {:noreply, state}
      {:ok, data} ->
        PriceOracle.on_market_update(:polymarket, data)
        {:noreply, state}
      _ ->
        {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("[Polymarket] unexpected: #{inspect(msg)}")
    {:noreply, state}
  end

  # WebSockex callbacks
  def handle_connect(conn, state) do
    Logger.info("[Polymarket] WebSocket connected")
    subscribe(conn)
    {:ok, %{state | ws_conn: conn, connected?: true}}
  end

  def handle_disconnect(_conn_state, state) do
    Logger.warning("[Polymarket] WebSocket disconnected")
    {:ok, %{state | connected?: false}}
  end

  def handle_frame({:text, json}, state) do
    case Jason.decode(json) do
      {:ok, %{"type" => "order_ack", "order" => order, "success" => true}} ->
        {{reply_to, _order}, pending} = Map.pop(state.pending_orders, order["orderID"])
        send(reply_to, {:ok, order})
        {:ok, %{state | pending_orders: pending}}
      {:ok, data} ->
        PriceOracle.on_market_update(:polymarket, data)
        {:ok, state}
      _ ->
        {:ok, state}
    end
  end

  defp connect(opts) do
    address = Keyword.fetch!(opts, :address)
    signer = Signer.from_env!()
    state = %__MODULE__{signer: signer, address: address, pending_orders: %{}, connected?: false}
    start_websocket(state)
  end

  defp start_websocket(state) do
    case WebSockex.start_link(@ws_url, __MODULE__, state) do
      {:ok, conn} -> {:ok, %{state | ws_conn: conn, connected?: true}}
      {:error, reason} ->
        Logger.error("[Polymarket] connect failed: #{inspect(reason)}")
        {:ok, state}
    end
  end

  defp connect_reconnect(state) do
    address = state.address
    signer = state.signer
    new_state = %__MODULE__{state | address: address, signer: signer, pending_orders: %{}, connected?: false}
    start_websocket(new_state)
  end

  defp subscribe(conn) do
    msg = Jason.encode!(%{type: "subscribe", channel: "prices", markets: ["*"]})
    send(conn, {:send, {:text, msg}})
  end
end
