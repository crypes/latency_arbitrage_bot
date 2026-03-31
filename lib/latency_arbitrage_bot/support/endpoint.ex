defmodule LatencyArbitrageBot.Support.Endpoint do
  @moduledoc "HTTP health + metrics endpoint on port 4000."
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.CORS
  plug Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason
  plug :dispatch

  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok", ts: System.system_time(:second)}))
  end

  get "/metrics" do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics_text())
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp metrics_text do
    # Prometheus-style metrics (stub)
    """
    # HELP latency_arbitrage_trades_total Total number of trades
    # TYPE latency_arbitrage_trades_total counter
    latency_arbitrage_trades_total 0
    """
  end
end
