defmodule RetroHexChatWeb.SitemapController do
  @moduledoc """
  Serves `/sitemap.xml` with all landing page and help topic URLs for search engine indexing.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.HelpTopics

  @landing_pages [
    {"/", "weekly", "1.0"},
    {"/about", "monthly", "0.8"},
    {"/how-it-works", "monthly", "0.8"},
    {"/features", "monthly", "0.8"},
    {"/privacy", "monthly", "0.7"},
    {"/install", "monthly", "0.7"},
    {"/community", "monthly", "0.6"},
    {"/faq", "monthly", "0.6"}
  ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    topics = HelpTopics.all_topics()

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, build_sitemap(topics))
  end

  @spec build_sitemap([map()]) :: String.t()
  defp build_sitemap(topics) do
    today = Date.utc_today() |> Date.to_iso8601()

    landing_urls =
      Enum.map_join(@landing_pages, "\n", fn {path, freq, priority} ->
        """
          <url>
            <loc>https://retrohexchat.com#{path}</loc>
            <lastmod>#{today}</lastmod>
            <changefreq>#{freq}</changefreq>
            <priority>#{priority}</priority>
          </url>\
        """
      end)

    help_urls =
      Enum.map_join(topics, "\n", fn topic ->
        """
          <url>
            <loc>https://retrohexchat.com/chat/help?topic=#{topic.id}</loc>
            <lastmod>#{today}</lastmod>
            <changefreq>monthly</changefreq>
            <priority>0.6</priority>
          </url>\
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url>
        <loc>https://retrohexchat.com/chat/help</loc>
        <lastmod>#{today}</lastmod>
        <changefreq>weekly</changefreq>
        <priority>0.8</priority>
      </url>
    #{landing_urls}
    #{help_urls}
    </urlset>
    """
  end
end
