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

  alias RetroHexChat.Net.GuardedRequest

  @max_redirects 3
  @max_body_size 2_000_000
  @timeout_ms 15_000

  @impl true
  @spec fetch(String.t(), String.t() | nil, String.t() | nil) ::
          RetroHexChat.Bots.Capabilities.RSS.Fetcher.result()
  def fetch(url, etag, last_modified) do
    # Checked again at fetch time, not only when the feed was added: a name that
    # resolved to a public address last month can be re-pointed at loopback
    # today, and the poll would follow it.
    url
    |> GuardedRequest.get(
      headers: conditional_headers(etag, last_modified),
      max_body_size: @max_body_size,
      timeout_ms: @timeout_ms,
      max_redirects: @max_redirects,
      overrides: :rss_req_options
    )
    |> case do
      {:ok, response, _final_url} ->
        handle_response(response)

      {:error, {:blocked, reason}} ->
        {:error, {:blocked, reason}}

      {:error, :too_many_redirects} ->
        {:error, dgettext("bots", "too many redirects")}

      {:error, :redirect_without_location} ->
        {:error, dgettext("bots", "redirect without location")}

      {:error, {:transport, reason}} ->
        {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @spec handle_response(Req.Response.t()) :: RetroHexChat.Bots.Capabilities.RSS.Fetcher.result()
  defp handle_response(response) do
    case response do
      %{status: 200, body: body} when is_binary(body) and byte_size(body) >= @max_body_size ->
        {:error, dgettext("bots", "feed body too large")}

      %{status: 200, body: body, headers: resp_headers} ->
        {:ok, to_string(body), cache_headers(resp_headers)}

      %{status: 304} ->
        {:not_modified}

      %{status: status} ->
        {:error, {:http_status, status}}
    end
  end

  @spec conditional_headers(String.t() | nil, String.t() | nil) :: [{String.t(), String.t()}]
  defp conditional_headers(etag, last_modified) do
    headers = [{"user-agent", "RetroHexChat-RSS/1.0"}]
    headers = if etag, do: [{"if-none-match", etag} | headers], else: headers
    if last_modified, do: [{"if-modified-since", last_modified} | headers], else: headers
  end

  @spec cache_headers(map()) :: RetroHexChat.Bots.Capabilities.RSS.Fetcher.headers()
  defp cache_headers(headers) do
    %{
      etag: GuardedRequest.first_header(headers, "etag"),
      last_modified: GuardedRequest.first_header(headers, "last-modified")
    }
  end
end
