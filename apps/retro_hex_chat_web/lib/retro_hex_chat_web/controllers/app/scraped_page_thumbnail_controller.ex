defmodule RetroHexChatWeb.App.ScrapedPageThumbnailController do
  @moduledoc """
  Serves scraped-page thumbnails through stable application URLs.
  """

  use RetroHexChatWeb, :controller

  alias RetroHexChat.Scraper.ImageCache

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"url_hash" => url_hash}) do
    case ImageCache.thumbnail_response(url_hash, expires_in: 300) do
      {:ok, {:redirect, url}} ->
        conn
        |> put_resp_header("cache-control", "public, max-age=60")
        |> redirect(external: url)

      {:ok, {:placeholder, status}} ->
        placeholder(conn, status)

      {:error, _reason} ->
        send_resp(conn, :not_found, "")
    end
  end

  @spec placeholder(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  defp placeholder(conn, status) do
    conn
    |> put_resp_header("cache-control", "public, max-age=60")
    |> put_resp_content_type("image/svg+xml", "utf-8")
    |> send_resp(200, placeholder_svg(status))
  end

  @spec placeholder_svg(String.t()) :: String.t()
  defp placeholder_svg(status) do
    title = dgettext("chat", "Image unavailable")
    detail = placeholder_detail(status)

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360" role="img" aria-labelledby="title desc">
      <title id="title">#{svg_escape(title)}</title>
      <desc id="desc">#{svg_escape(detail)}</desc>
      <rect width="640" height="360" fill="#f3f4f6"/>
      <rect x="1" y="1" width="638" height="358" fill="none" stroke="#cbd5e1" stroke-width="2"/>
      <g fill="none" stroke="#64748b" stroke-width="8" stroke-linecap="round" stroke-linejoin="round">
        <rect x="252" y="82" width="136" height="104" rx="10"/>
        <path d="M274 164l35-36 30 29 17-18 30 25"/>
        <circle cx="355" cy="114" r="13"/>
        <path d="M246 74l148 120"/>
      </g>
      <text x="320" y="236" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="26" font-weight="700" fill="#334155">#{svg_escape(title)}</text>
      <text x="320" y="272" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="18" fill="#64748b">#{svg_escape(detail)}</text>
    </svg>
    """
  end

  @spec placeholder_detail(String.t()) :: String.t()
  defp placeholder_detail("pending"), do: dgettext("chat", "Thumbnail is being prepared")
  defp placeholder_detail(_status), do: dgettext("chat", "Thumbnail could not be loaded")

  @spec svg_escape(String.t()) :: String.t()
  defp svg_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
