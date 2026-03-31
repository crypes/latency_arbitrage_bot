defmodule LatencyArbitrageBot.Venues.Kalshi.Adapter do
  @moduledoc """
  Kalshi venue adapter.

  ## Auth (RSA-SHA256)
  Signature payload = timestamp <> method <> path_stripped_of_query
  Signed with RSA-SHA256/PKCS1_PSS, salt=digest_length, encoded base64.

  ## Fixed-point
  All dollar prices are transmitted as strings multiplied by 100.
  E.g. 0.55 dollars -> 55 in fp. Decode with Decimal.div(value, 100).

  ## Environments
  - Demo: https://demo-api.kalshi.co/trade-api/v2
  - Prod:  https://api.kalshi.com/trade-api/v2
  """

  use GenServer, restart: :permanent
  require Logger

  alias LatencyArbitrageBot.Venues.Kalshi.Signer

  @base_url "https://demo-api.kalshi.co/trade-api/v2"

  defstruct [:key_id, :private_key_pem, :session, :sequence, :rate_limit_ms]

  @impl true
  def init(opts) do
    key_id = Keyword.fetch!(opts, :key_id)
    pem = Keyword.fetch!(opts, :private_key_pem)
    rate_limit_ms = opts[:rate_limit_ms] || 200
    {:ok, session} = :inets.start()
    :ok = :ssl.start()
    {:ok, %__MODULE__{
      key_id: key_id,
      private_key_pem: pem,
      session: nil,
      sequence: 0,
      rate_limit_ms: rate_limit_ms
    }}
  end

  @impl true
  def handle_cast({:place_order, market_ticker, side, dollars_fp, count_fp, reply_to}, state) do
    body = Jason.encode!(%{
      market_ticker: market_ticker,
      side: side,
      dollars_fp: dollars_fp,
      count_fp: count_fp,
      type: "limit"
    })
    path = "/orders"
    case sign_and_request(:POST, path, body, state) do
      {:ok, resp} -> send(reply_to, {:ok, resp})
      {:error, reason} -> send(reply_to, {:error, reason})
    end
    {:noreply, state}
  end

  @doc "Place a limit order. Returns {:ok, order} or {:error, reason}."
  def place_order(pid, market_ticker, side, dollars_fp, count_fp) do
    GenServer.cast(pid, {:place_order, market_ticker, side, dollars_fp, count_fp, self()})
    receive do
      result -> result
    after 5_000 -> {:error, :timeout} end
  end

  defp sign_and_request(method, path, body, state) do
    timestamp = :os.system_time(:millisecond) |> Integer.to_string()
    method_str = method |> Atom.to_string() |> String.upcase()
    signed = Signer.sign(timestamp, method_str, path, state.private_key_pem)
    headers = [
      {"Content-Type", "application/json"},
      {"KALSHI-AUTHENTICATION", state.key_id <> ":" <> signed},
      {"KALSHI-TIMESTAMP", timestamp}
    ]
    httpc_req(method, path, headers, body)
  end

  defp httpc_req(method, path, headers, body) do
    URL = String.to_charlist(@base_url <> path)
    Httpc.request(method, URL, headers, body, [])
    |> case do
      {:ok, {{_, 200, _}, _headers, resp_body}} ->
        {:ok, Jason.decode!(resp_body)}
      {:ok, {{_, status, _}, _headers, resp_body}} ->
        {:error, {:http_error, status, resp_body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
