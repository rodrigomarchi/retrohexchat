defmodule RetroHexChat.Bots.Capabilities.RSS.Fetcher do
  @moduledoc """
  How the RSS capability gets bytes from a feed address.

  Injected rather than called directly, for the same reason the translation
  pipeline injects its engine: the interesting behaviour is what happens *after*
  the bytes arrive — a new item announced, an old one kept quiet, a failure
  recorded on the feed — and none of that should need the internet to be tested.

  The guard means a test cannot serve a fixture from loopback either, which
  would otherwise be the easy way out.
  """

  @type headers :: %{etag: String.t() | nil, last_modified: String.t() | nil}
  @type result :: {:ok, String.t(), headers()} | {:not_modified} | {:error, term()}

  @callback fetch(url :: String.t(), etag :: String.t() | nil, last_modified :: String.t() | nil) ::
              result()

  @doc "The fetcher in force. Configure `:rss_fetcher` to substitute one."
  @spec impl() :: module()
  def impl do
    Application.get_env(:retro_hex_chat, :rss_fetcher, __MODULE__.HTTP)
  end
end

defmodule RetroHexChat.Bots.Capabilities.RSS.Fetcher.HTTP do
  @moduledoc """
  Fetches a feed over HTTP, refusing addresses the server should not reach.

  Conditional requests are sent when the feed has given an ETag or a
  Last-Modified: a well-behaved publisher then answers `304` and the poll costs
  nothing on either side.
  """
  use Gettext, backend: RetroHexChat.Gettext

  @behaviour RetroHexChat.Bots.Capabilities.RSS.Fetcher

  alias RetroHexChat.Net.URLGuard

  @max_redirects 3
  @max_body_size 2_000_000
  @timeout_ms 15_000
  @redirect_statuses [301, 302, 303, 307, 308]

  @impl true
  @spec fetch(String.t(), String.t() | nil, String.t() | nil) ::
          RetroHexChat.Bots.Capabilities.RSS.Fetcher.result()
  def fetch(url, etag, last_modified) do
    # Checked again at fetch time, not only when the feed was added: a name that
    # resolved to a public address last month can be re-pointed at loopback
    # today, and the poll would follow it.
    request(url, etag, last_modified, @max_redirects)
  rescue
    e -> {:error, Exception.message(e)}
  end

  @spec request(String.t(), String.t() | nil, String.t() | nil, integer()) ::
          RetroHexChat.Bots.Capabilities.RSS.Fetcher.result()
  defp request(_url, _etag, _last_modified, redirects_left) when redirects_left < 0,
    do: {:error, dgettext("bots", "too many redirects")}

  defp request(url, etag, last_modified, redirects_left) do
    with {:ok, target} <- URLGuard.fetch_target(url),
         {:ok, response} <- Req.get(request_options(target, etag, last_modified)) do
      handle_response(response, url, etag, last_modified, redirects_left)
    else
      {:error, reason} when is_binary(reason) -> {:error, {:blocked, reason}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec handle_response(
          Req.Response.t(),
          String.t(),
          String.t() | nil,
          String.t() | nil,
          integer()
        ) ::
          RetroHexChat.Bots.Capabilities.RSS.Fetcher.result()
  defp handle_response(response, url, etag, last_modified, redirects_left) do
    case response do
      %{status: 200, body: body} when is_binary(body) and byte_size(body) >= @max_body_size ->
        {:error, dgettext("bots", "feed body too large")}

      %{status: 200, body: body, headers: resp_headers} ->
        {:ok, to_string(body), cache_headers(resp_headers)}

      %{status: 304} ->
        {:not_modified}

      %{status: status, headers: headers} when status in @redirect_statuses ->
        follow_redirect(url, headers, etag, last_modified, redirects_left)

      %{status: status} ->
        {:error, dgettext("bots", "HTTP %{status}", status: status)}
    end
  end

  @spec request_options(URLGuard.fetch_target(), String.t() | nil, String.t() | nil) :: keyword()
  defp request_options(target, etag, last_modified) do
    options = [
      url: target.url,
      headers: conditional_headers(etag, last_modified),
      redirect: false,
      compressed: false,
      decode_body: false,
      max_retries: 0,
      into: &collect_limited_body/2,
      connect_options: Keyword.put(target.connect_options, :timeout, @timeout_ms),
      receive_timeout: @timeout_ms
    ]

    if Map.get(target, :inet6?) do
      Keyword.put(options, :inet6, true)
    else
      options
    end
  end

  @spec follow_redirect(String.t(), map(), String.t() | nil, String.t() | nil, integer()) ::
          RetroHexChat.Bots.Capabilities.RSS.Fetcher.result()
  defp follow_redirect(url, headers, etag, last_modified, redirects_left) do
    case redirect_url(url, first_header(headers, "location")) do
      nil -> {:error, dgettext("bots", "redirect without location")}
      next_url -> request(next_url, etag, last_modified, redirects_left - 1)
    end
  end

  @spec collect_limited_body(
          {:data, binary()},
          {Req.Request.t(), Req.Response.t()}
        ) ::
          {:cont | :halt, {Req.Request.t(), Req.Response.t()}}
  defp collect_limited_body({:data, data}, {request, response}) do
    current = if is_binary(response.body), do: response.body, else: ""
    remaining = max(@max_body_size - byte_size(current), 0)
    data = binary_part(data, 0, min(byte_size(data), remaining))
    response = %{response | body: current <> data}

    if byte_size(response.body) >= @max_body_size do
      {:halt, {request, response}}
    else
      {:cont, {request, response}}
    end
  end

  @spec redirect_url(String.t(), String.t() | nil) :: String.t() | nil
  defp redirect_url(_url, nil), do: nil

  defp redirect_url(url, location) do
    url
    |> URI.merge(String.trim(location))
    |> URI.to_string()
  rescue
    _ -> nil
  end

  @spec conditional_headers(String.t() | nil, String.t() | nil) :: [{String.t(), String.t()}]
  defp conditional_headers(etag, last_modified) do
    headers = [{"user-agent", "RetroHexChat-RSS/1.0"}]
    headers = if etag, do: [{"if-none-match", etag} | headers], else: headers
    if last_modified, do: [{"if-modified-since", last_modified} | headers], else: headers
  end

  @spec cache_headers(map()) :: RetroHexChat.Bots.Capabilities.RSS.Fetcher.headers()
  defp cache_headers(headers) do
    %{etag: first_header(headers, "etag"), last_modified: first_header(headers, "last-modified")}
  end

  @spec first_header(map(), String.t()) :: String.t() | nil
  defp first_header(headers, name) do
    case Map.get(headers, name) do
      [value | _] -> value
      value when is_binary(value) -> value
      _ -> nil
    end
  end
end
