defmodule RetroHexChat.Net.URLGuard do
  @moduledoc """
  Decides whether a URL is safe for the server to fetch.

  Any server-side fetch of a URL supplied by a user or an external feed can turn
  into SSRF if it is not checked. The guard rejects non-HTTP schemes, missing
  hosts, and names that resolve to addresses the public internet cannot route to.
  """

  @type verdict :: :ok | {:error, String.t()}
  @type fetch_target :: %{
          url: String.t(),
          hostname: String.t(),
          address: :inet.ip_address(),
          connect_options: keyword(),
          inet6?: boolean()
        }

  @allowed_schemes ~w(http https)

  @doc """
  Whether the server may fetch this URL.
  """
  @spec check(String.t()) :: verdict()
  def check(url) when is_binary(url) do
    case fetch_target(url) do
      {:ok, _target} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def check(_), do: {:error, "not an address"}

  @doc """
  Returns a request target pinned to a resolved, fetchable address.

  The returned URL uses the chosen IP address, while `:connect_options` carries
  the original hostname for the HTTP Host header, TLS SNI, and certificate
  verification. That keeps the fetch from doing a second DNS lookup after the
  safety check.
  """
  @spec fetch_target(String.t()) :: {:ok, fetch_target()} | {:error, String.t()}
  def fetch_target(url) when is_binary(url) do
    case parse_fetch_uri(url) do
      {:ok, uri} -> fetch_target_for_uri(uri)
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_target(_url), do: {:error, "not an address"}

  @doc """
  Whether an address belongs to a non-public range.

  Covers loopback, private ranges, link-local, carrier-grade NAT, documentation
  and benchmark ranges, multicast/reserved space, and the IPv6 equivalents,
  including v4-mapped addresses.
  """
  @spec private?(:inet.ip_address()) :: boolean()
  def private?({0, _, _, _}), do: true
  def private?({127, _, _, _}), do: true
  def private?({10, _, _, _}), do: true
  def private?({192, 168, _, _}), do: true
  def private?({169, 254, _, _}), do: true
  def private?({172, b, _, _}) when b >= 16 and b <= 31, do: true
  def private?({100, b, _, _}) when b >= 64 and b <= 127, do: true
  def private?({192, 0, 0, 9}), do: false
  def private?({192, 0, 0, 10}), do: false
  def private?({192, 0, 0, _}), do: true
  def private?({192, 0, 2, _}), do: true
  def private?({192, 88, 99, _}), do: true
  def private?({198, b, _, _}) when b in 18..19, do: true
  def private?({198, 51, 100, _}), do: true
  def private?({203, 0, 113, _}), do: true
  def private?({a, _, _, _}) when a >= 224, do: true
  def private?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  def private?({0, 0, 0, 0, 0, 0, 0, 0}), do: true

  # ::ffff:a.b.c.d, the same IPv4 address through an IPv6 spelling.
  def private?({0, 0, 0, 0, 0, 0xFFFF, ab, cd}) do
    private?({div(ab, 256), rem(ab, 256), div(cd, 256), rem(cd, 256)})
  end

  # Deprecated IPv4-compatible IPv6 addresses (::a.b.c.d).
  def private?({0, 0, 0, 0, 0, 0, _ab, _cd}), do: true

  # 64:ff9b::/96 well-known NAT64 prefix.
  def private?({0x0064, 0xFF9B, 0, 0, 0, 0, _ab, _cd}), do: true

  # 100::/64 discard-only.
  def private?({0x0100, 0, 0, 0, _, _, _, _}), do: true

  # Documentation, benchmarking, and 6to4 special-use blocks.
  def private?({0x2001, 0x0002, _, _, _, _, _, _}), do: true
  def private?({0x2001, 0x0DB8, _, _, _, _, _, _}), do: true
  def private?({0x2002, _, _, _, _, _, _, _}), do: true

  # fc00::/7 unique-local, fe80::/10 link/site-local, ff00::/8 multicast.
  def private?({a, _, _, _, _, _, _, _}) when a >= 0xFC00 and a <= 0xFDFF, do: true
  def private?({a, _, _, _, _, _, _, _}) when a >= 0xFE80 and a <= 0xFEFF, do: true
  def private?({a, _, _, _, _, _, _, _}) when a >= 0xFF00 and a <= 0xFFFF, do: true
  def private?(_), do: false

  @spec parse_fetch_uri(String.t()) :: {:ok, URI.t()} | {:error, String.t()}
  defp parse_fetch_uri(url) do
    uri = URI.parse(url)
    scheme = uri.scheme && String.downcase(uri.scheme)

    cond do
      scheme not in @allowed_schemes ->
        {:error, "only http and https addresses can be fetched"}

      not (is_binary(uri.host) and uri.host != "") ->
        {:error, "the address has no host"}

      is_binary(uri.userinfo) and uri.userinfo != "" ->
        {:error, "addresses with embedded credentials cannot be fetched"}

      true ->
        {:ok, %{uri | scheme: scheme, fragment: nil}}
    end
  rescue
    _ -> {:error, "not an address"}
  end

  @spec fetch_target_for_uri(URI.t()) :: {:ok, fetch_target()} | {:error, String.t()}
  defp fetch_target_for_uri(uri) do
    case resolve(uri.host) do
      {:ok, addresses} -> target_for_addresses(uri, addresses)
      {:error, reason} -> {:error, "#{uri.host} does not resolve (#{reason})"}
    end
  end

  @spec target_for_addresses(URI.t(), [:inet.ip_address()]) ::
          {:ok, fetch_target()} | {:error, String.t()}
  defp target_for_addresses(uri, addresses) do
    case choose_address(uri.host, addresses) do
      {:ok, address} -> {:ok, build_target(uri, address)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec choose_address(String.t(), [:inet.ip_address()]) ::
          {:ok, :inet.ip_address()} | {:error, String.t()}
  defp choose_address(host, []), do: {:error, "#{host} does not resolve (nxdomain)"}

  defp choose_address(host, addresses) do
    private_address = Enum.find(addresses, &private?/1)

    cond do
      allow_private?() ->
        {:ok, hd(addresses)}

      private_address ->
        {:error,
         "#{host} resolves to #{:inet.ntoa(private_address)}, which is not a public address"}

      true ->
        {:ok, hd(addresses)}
    end
  end

  @spec build_target(URI.t(), :inet.ip_address()) :: fetch_target()
  defp build_target(%URI{host: hostname} = uri, address) do
    %{
      url: URI.to_string(%{uri | host: address_to_host(address)}),
      hostname: hostname,
      address: address,
      connect_options: [hostname: hostname],
      inet6?: tuple_size(address) == 8
    }
  end

  @spec address_to_host(:inet.ip_address()) :: String.t()
  defp address_to_host(address), do: address |> :inet.ntoa() |> to_string()

  @spec allow_private?() :: boolean()
  defp allow_private? do
    Application.get_env(:retro_hex_chat, :allow_private_fetch_addresses, false) == true or
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
end
