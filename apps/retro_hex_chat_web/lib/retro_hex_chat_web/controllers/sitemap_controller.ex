defmodule RetroHexChatWeb.SitemapController do
  @moduledoc """
  Serves `/sitemap.xml` with all help topic URLs for search engine indexing.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.HelpTopics

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    topics = HelpTopics.all_topics()

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, build_sitemap(topics))
  end

  @spec build_sitemap([map()]) :: String.t()
  defp build_sitemap(topics) do
    urls =
      Enum.map_join(topics, "\n", fn topic ->
        """
          <url>
            <loc>https://retrohexchat.com/chat/help?topic=#{topic.id}</loc>
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
        <changefreq>weekly</changefreq>
        <priority>0.8</priority>
      </url>
    #{urls}
    </urlset>
    """
  end
end
