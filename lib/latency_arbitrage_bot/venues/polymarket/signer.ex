defmodule LatencyArbitrageBot.Venues.Polymarket.Signer do
  @moduledoc """
  EIP-712 signer for Polymarket CLOB orders.

  Polymarket uses EIP-712 typed structured-data signatures.
  The signer takes an order payload, structures it per Polymarket's
  EIP-712 domain, hashes it, and signs with the wallet private key
  stored in the :private_key application env.

  IMPORTANT: Never log or expose the private key.
  """
  import Bitwise

  @domain_separator %{
    "name" => "Polymarket",
    "version" => "1",
    "chainId" => 137,          # Polygon mainnet
    "verifyingContract" => "0x0000000000000000000000000000000000000000"  # CLOB contract
  }

  @type payload :: %{
          optional(String.t()) => String.t() | number()
        }

  @spec sign_payload(payload()) :: {:ok, String.t()} | {:error, atom()}
  def sign_payload(payload) do
    with {:ok, key} <- fetch_private_key(),
         {:ok, typed_data} <- build_typed_data(payload),
         {:ok, digest} <- hash_typed_data(typed_data),
         {:ok, sig} <- sign_digest(digest, key) do
      {:ok, "0x" <> sig}
    else
      {:error, _} = err -> err
    end
  end

  # ─── Private key — loaded from application env at runtime ────────────────────

  defp fetch_private_key do
    case Application.get_env(:latency_arbitrage_bot, :polymarket_private_key) do
      nil -> {:error, :no_private_key_configured}
      "0x" <> hex = when is_binary(hex) -> {:ok, hex}
      hex when is_binary(hex) -> {:ok, hex}
    end
  end

  # ─── EIP-712 typed data construction ─────────────────────────────────────────

  defp build_typed_data(payload) do
    # Polymarket Order struct:
    order_struct = %{
      "conditionId" => Map.get(payload, "conditionId", ""),
      "outcome" => Map.get(payload, "outcome", ""),
      "side" => Map.get(payload, "side", ""),
      "price" => Map.get(payload, "price", "0"),
      "size" => Map.get(payload, "size", "0")
    }

    typed_data = %{
      "types" => %{
        "EIP712Domain" => [
          %{"name" => "name", "type" => "string"},
          %{"name" => "version", "type" => "string"},
          %{"name" => "chainId", "type" => "uint256"},
          %{"name" => "verifyingContract", "type" => "address"}
        ],
        "Order" => [
          %{"name" => "conditionId", "type" => "bytes32"},
          %{"name" => "outcome", "type" => "string"},
          %{"name" => "side", "type" => "string"},
          %{"name" => "price", "type" => "uint256"},
          %{"name" => "size", "type" => "uint256"}
        ]
      },
      "primaryType" => "Order",
      "domain" => @domain_separator,
      "message" => order_struct
    }

    {:ok, typed_data}
  end

  defp hash_typed_data(typed_data) do
    # RFC-8017 ECDSA SHA-256 digest of the typed data structure
    json = Jason.encode!(typed_data)
    digest = :crypto.hash(:sha256, json)
    {:ok, digest}
  end

  defp sign_digest(digest, hex_key) do
    {:ok, sign(digest, hex_key)}
  rescue
    _ -> {:error, :signing_failed}
  end

  # NOTE: This is a simplified stub. In production:
  # - Use LibSodium (:crypto.sign/2 with ECDSA on secp256k1) OR
  # - Delegate to a local Geth node (personal_sign) for production-grade key mgmt
  # - NEVER store raw private keys in application env in prod
  defp sign(_digest, _hex_key) do
    # PLACEHOLDER — replace with:
    #   1. A local Geth node's personal_sign API, OR
    #   2. LibSodium sign_seed/2 (Ed25519), OR
    #   3. :crypto.sign/2 with :ecdsadsa, :secp256k1, :sha256
    "PLACEHOLDER_REPLACE_WITH_REAL_SIGNATURE"
  end
end
