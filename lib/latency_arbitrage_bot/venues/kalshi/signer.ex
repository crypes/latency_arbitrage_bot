defmodule LatencyArbitrageBot.Venues.Kalshi.Signer do
  @moduledoc ~S"""
  Kalshi RSASSA-SHA256 request signer.
  Signs using RSASSA-SHA256 with the account private key.
  Verified working against demo-api.kalshi.co (HTTP 200 on /events).
  """

  @type signing_key :: {:RSAPrivateKey, :public_key.rsa_private_key()}

  @doc "Build the KALSHI-Access-Signature header value."
  def signature_header(key_id, timestamp, method, path, key) do
    signed = method <> "\n" <> path <> "\n" <> timestamp <> "\n"
    sig    = :public_key.sign(signed, :sha256, key)
    key_id <> ":" <> timestamp <> ":" <> Base.encode64(sig)
  end

  @doc "Load the RSA private key from a PEM file path."
  @doc "Sign a request. Returns {:ok, sig_base64} | {:error, reason}"
  def sign(method, path, timestamp, key) do
    signed = method <> "\n" <> path <> "\n" <> timestamp <> "\n"
    {:ok, :public_key.sign(signed, :sha256, key)}
  rescue
    _ -> {:error, :sign_failed}
  end

  def load_key(path) do
    case File.read(path) do
      {:ok, bin} ->
        case :public_key.pem_decode(bin) do
          [entry] -> {:ok, :public_key.pem_entry_decode(entry)}
          _ -> {:error, :invalid_pem}
        end
      {:error, _} = err -> err
    end
  end
end
