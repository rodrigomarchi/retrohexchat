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

  alias RetroHexChat.Bots.Capabilities.RSS.UrlGuard

  @impl true
  @spec fetch(String.t(), String.t() | nil, String.t() | nil) ::
          RetroHexChat.Bots.Capabilities.RSS.Fetcher.result()
  def fetch(url, etag, last_modified) do
    # Checked again at fetch time, not only when the feed was added: a name that
    # resolved to a public address last month can be re-pointed at loopback
    # today, and the poll would follow it.
    case UrlGuard.check(url) do
      :ok -> request(url, etag, last_modified)
      {:error, reason} -> {:error, {:blocked, reason}}
    end
  end

  @spec request(String.t(), String.t() | nil, String.t() | nil) ::
          RetroHexChat.Bots.Capabilities.RSS.Fetcher.result()
  defp request(url, etag, last_modified) do
    case Req.get(url, headers: conditional_headers(etag, last_modified), receive_timeout: 15_000) do
      {:ok, %{status: 200, body: body, headers: resp_headers}} ->
        {:ok, to_string(body), cache_headers(resp_headers)}

      {:ok, %{status: 304}} ->
        {:not_modified}

      {:ok, %{status: status}} ->
        {:error, dgettext("bots", "HTTP %{status}", status: status)}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
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
