defmodule LatencyArbitrageBot.Venues.Supervisor do
  @moduledoc "OTP Supervisor that starts and monitors all venue adapters."
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Polymarket — started directly by Application
      # Add Kalshi and Coinbase adapters here once API access is confirmed
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
