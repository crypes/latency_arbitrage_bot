defmodule LatencyArbitrageBot.Venues.Polymarket.Signer do
  @moduledoc ~S"""
  Polymarket request signer using Ed25519.
  """

  @doc "Sign a payload with the Ed25519 private key."
  def sign_payload(payload, priv_key) do
    :crypto.sign(:eddsa, :none, payload, priv_key)
    |> Base.encode16(case: :lower)
  end

  @doc "Load Ed25519 key from hex string."
  def load_hex_key(hex) do
    {:ok, :public_key.der_decode(:ECPrivateKey, Base.decode16!(String.downcase(hex)))}
  rescue
    _ -> {:error, :invalid_key}
  end

  @doc "Load key from env."
  def from_env! do
    key_hex = Application.fetch_env!(:latency_arbitrage_bot, :polymarket_signing_key)
    case load_hex_key(key_hex) do
      {:ok, key} -> key
      {:error, _} -> raise "Invalid Polymarket signing key"
    end
  end
end
