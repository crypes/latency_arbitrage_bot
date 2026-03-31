defmodule LatencyArbitrageBot.Venues.Kalshi.Signer do
  @moduledoc """
  RSA-SHA256 request signer for the Kalshi Trade API.

  Payload = timestamp <> HTTP_METHOD <> path_stripped_of_query_params
  Signature: RSA-SHA256/PKCS1_PSS, salt_length = DIGEST_LENGTH
  Output: base64-encoded

  ## Headers added to every authenticated request:
  - KALSHI-ACCESS-KEY        (the key ID / api_key_id)
  - KALSHI-ACCESS-TIMESTAMP  (epoch ms as string)
  - KALSHI-ACCESS-SIGNATURE  (base64 sig)
  """

  @type method :: :GET | :POST | :DELETE | :PUT

  @doc "Build the full auth header map for an authenticated HTTP request."
  @spec auth_headers(method(), String.t(), String.t(), String.t()) :: [{String.t(), String.t()}]
  def auth_headers(method, path, api_key_id, private_key_pem) do
    ts = timestamp_ms()
    # Strip query string from path before signing
    clean_path = String.split(path, "?") |> hd()
    msg = "#{ts}#{Atom.to_string(method)}#{clean_path}"

    sig = sign_rsa_pss(private_key_pem, msg)

    [
      {"Content-Type", "application/json"},
      {"KALSHI-ACCESS-KEY", api_key_id},
      {"KALSHI-ACCESS-TIMESTAMP", ts},
      {"KALSHI-ACCESS-SIGNATURE", sig}
    ]
  end

  @doc "Alias for use when key_id/key come from app env."
  def auth_headers(method, path) do
    auth_headers(
      method,
      path,
      Application.get_env(:latency_arbitrage_bot, :kalshi_api_key_id, ""),
      Application.get_env(:latency_arbitrage_bot, :kalshi_api_key, "")
    )
  end

  @doc "WS auth headers (same sig mechanism)."
  def ws_auth_headers(api_key_id, private_key_pem) do
    ts = timestamp_ms()
    msg = "#{ts}#{:GET}wss://ws.trade-api.kalshi.co/trade-api/v2/ws"
    sig = sign_rsa_pss(private_key_pem, msg)

    [
      {"KALSHI-ACCESS-KEY", api_key_id},
      {"KALSHI-ACCESS-TIMESTAMP", ts},
      {"KALSHI-ACCESS-SIGNATURE", sig}
    ]
  end

  # ─── Private ────────────────────────────────────────────────────────────────

  defp timestamp_ms, do: System.system_time(:millisecond) |> Integer.to_string()

  defp sign_rsa_pss(pem, msg) when is_binary(pem) and is_binary(msg) do
    der = pem_to_der(pem)
    {:RSAPrivateKey, _, components, _, _, _, _, _, _, _} = :public_key.pem_entry_decode(der)

    # RSAPrivateKey ::= SEQUENCE { version, n, e, d, p, q, dP, dQ, qi }
    n = elem(components, 1)
    e = elem(components, 2)
    d = elem(components, 3)
    p = elem(components, 4)
    q = elem(components, 5)
    dP = elem(components, 6)
    dQ = elem(components, 7)
    qi = elem(components, 8)

    rsa_priv = {:RSAPrivateKey, n, e, d, p, q, dP, dQ, qi}
    der_priv = :public_key.der_encode(:RSAPrivateKey, rsa_priv)

    digest = :crypto.hash(:sha256, msg)

    # RSA PSS with SHA256, salt length = digest length (32 bytes)
    sig = :public_key.sign({:digest, digest}, :sha, der_priv, [
      rsa_padding: :rsa_pkcs1_pss_padding,
      rsa_mgf1_md: :sha256,
      rsa_PSS_saltlen: :digest
    ])

    Base.encode64(sig)
  end

  defp pem_to_der(pem) do
    [{:RSAPrIVATEKey, der, _}] = :public_key.pem_decode(pem)
    der
  end
end
