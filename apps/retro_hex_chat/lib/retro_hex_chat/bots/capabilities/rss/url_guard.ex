defmodule RetroHexChat.Bots.Capabilities.RSS.UrlGuard do
  @moduledoc """
  Decides whether a feed URL is safe for the server to fetch.

  A feed address is typed by a person and fetched by the server, which sits
  inside a network the person is not on. Left unchecked that turns the bot into
  a proxy for reaching whatever the host can reach — the metadata service on a
  link-local address, a database on loopback, a neighbour on the private range.
  Nothing about the request looks unusual from outside; the only defence is
  refusing the address.

  The check resolves the hostname, because `http://internal.example.com/` can
  point at 127.0.0.1 just as easily as `http://127.0.0.1/` does.
  """

  @type verdict :: :ok | {:error, String.t()}

  @allowed_schemes ~w(http https)

  @doc """
  Whether the server may fetch this URL.

  Refuses anything that is not http(s), has no host, or resolves to an address
  that is not reachable from the public internet.
  """
  @spec check(String.t()) :: verdict()
  def check(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme} when scheme not in @allowed_schemes ->
        {:error, "only http and https addresses can be fetched"}

      %URI{host: host} when is_binary(host) and host != "" ->
        check_host(host)

      %URI{} ->
        {:error, "the address has no host"}
    end
  end

  def check(_), do: {:error, "not an address"}

  @spec check_host(String.t()) :: verdict()
  defp check_host(host) do
    case resolve(host) do
      {:ok, addresses} -> judge(host, Enum.find(addresses, &private?/1))
      {:error, reason} -> {:error, "#{host} does not resolve (#{reason})"}
    end
  end

  @spec judge(String.t(), :inet.ip_address() | nil) :: verdict()
  defp judge(_host, nil), do: :ok

  defp judge(host, addr) do
    if allow_private?() do
      :ok
    else
      {:error, "#{host} resolves to #{:inet.ntoa(addr)}, which is not a public address"}
    end
  end

  # Off everywhere but a test that needs to serve a feed to itself. The refusal
  # is the reason the real fetch path had no test at all: there is nowhere to put
  # a fixture that the guard will agree to read. Opening it under an explicit
  # flag is better than leaving the one path that talks to the network unproven.
  @spec allow_private?() :: boolean()
  defp allow_private? do
    Application.get_env(:retro_hex_chat, :rss_allow_private_addresses, false) == true
  end

  @spec resolve(String.t()) :: {:ok, [:inet.ip_address()]} | {:error, atom()}
  defp resolve(host) do
    charlist = String.to_charlist(host)

    v4 = :inet.getaddrs(charlist, :inet)
    v6 = :inet.getaddrs(charlist, :inet6)

    case {v4, v6} do
      {{:ok, a}, {:ok, b}} -> {:ok, a ++ b}
      {{:ok, a}, _} -> {:ok, a}
      {_, {:ok, b}} -> {:ok, b}
      {{:error, reason}, _} -> {:error, reason}
    end
  end

  @doc """
  Whether an address belongs to a range the public internet cannot route to.

  Covers loopback, private ranges, link-local (which is where cloud metadata
  services live), carrier-grade NAT, and the IPv6 equivalents — including
  v4-mapped addresses, which are the usual way a blocklist gets walked around.
  """
  @spec private?(:inet.ip_address()) :: boolean()
  def private?({127, _, _, _}), do: true
  def private?({10, _, _, _}), do: true
  def private?({192, 168, _, _}), do: true
  def private?({169, 254, _, _}), do: true
  def private?({0, _, _, _}), do: true
  def private?({172, b, _, _}) when b >= 16 and b <= 31, do: true
  def private?({100, b, _, _}) when b >= 64 and b <= 127, do: true
  def private?({a, _, _, _}) when a >= 224, do: true
  def private?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  def private?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  # ::ffff:a.b.c.d — the same v4 address wearing a v6 hat.
  def private?({0, 0, 0, 0, 0, 0xFFFF, ab, cd}) do
    private?({div(ab, 256), rem(ab, 256), div(cd, 256), rem(cd, 256)})
  end

  # fc00::/7 unique-local, fe80::/10 link-local.
  def private?({a, _, _, _, _, _, _, _}) when a >= 0xFC00 and a <= 0xFDFF, do: true
  def private?({a, _, _, _, _, _, _, _}) when a >= 0xFE80 and a <= 0xFEBF, do: true
  def private?(_), do: false
end
