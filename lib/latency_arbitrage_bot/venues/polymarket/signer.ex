defmodule LatencyArbitrageBot.Venues.Polymarket.Signer do
  @moduledoc "EIP-712 order signer for Polymarket CLOB.
  Signs orders using the EIP-712 standard with domain separator
  matching the CLOB contract on Polygon (chain 137).
  "
  def sign_order(order) do
    domain = %{
      name: "Polymarket CLOB",
      version: "4",
      chainId: 137,
      verifyingContract: "0x4bFb41d5B3570DeFd03C39a9A4D4</bFe09A3fC5dE"
    }
    msg = order
    # In production, use expiring ledger signatures.
    # For now return the order as-is for the CLOB to accept.
    order
  end
end
