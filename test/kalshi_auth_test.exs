# Run with: cd /home/workspace/latency_arbitrage_bot && mix run test/kalshi_auth_test.exs
Mix.install([])

# Load the Signer module inline for testing
defmodule Signer do
  def sign(timestamp, method, path, private_key_pem) do
    payload = timestamp <> method <> path
    signing_input = :crypto.hash(:sha256, payload)

    {:ok, private_key} = :public_key.pem_decode(private_key_pem) |> hd() |> :public_key.pem_entry_decode()
    salt_len = byte_size(signing_input)

    :public_key.sign(signing_input, {:rsa, :sha256, salt_len}, private_key)
    |> Base.encode64()
  end
end

key_id = "d2d7dc84-fda7-4d8d-a8dc-f4896f9ba63b"
pem = File.read!("config/kalshi_private_key.pem")

timestamp = :os.system_time(:millisecond) |> Integer.to_string()
method = "GET"
path = "/markets/BC-USD"

signature = Signer.sign(timestamp, method, path, pem)

header = "#{key_id}:#{signature}"
IO.puts("KALSHI-AUTHENTICATION: #{header}")
IO.puts("KALSHI-TIMESTAMP: #{timestamp}")
IO.puts("Signature length: #{byte_size(signature)} bytes (base64)")
IO.puts("Auth header length: #{byte_size(header)} bytes")
IO.puts("TEST: OK")
