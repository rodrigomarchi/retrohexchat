defmodule RetroHexChatWeb.SitemapController do
  @moduledoc """
  Serves `/sitemap.xml` with all landing page and help topic URLs for search engine indexing.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.SEO

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    topics = HelpTopics.all_topics()

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, build_sitemap(topics))
  end

  @spec build_sitemap([map()]) :: String.t()
  defp build_sitemap(topics) do
    paths =
      SEO.landing_paths() ++
        ["/chat/help"] ++ Enum.map(topics, &"/chat/help/#{&1.id}")

    entries =
      paths
      |> Enum.uniq()
      |> Enum.flat_map(&localized_url_entries/1)
      |> Enum.map_join("\n", &url_entry/1)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
    #{entries}
    </urlset>
    """
    |> String.trim_leading()
  end

  defp localized_url_entries(path) do
    path
    |> SEO.localized_urls()
    |> Enum.map(fn localized_url ->
      %{
        loc: localized_url.href,
        alternates: SEO.alternate_links(path)
      }
    end)
  end

  defp url_entry(%{loc: loc, alternates: alternates}) do
    alternate_links =
      Enum.map_join(alternates, "\n", fn alternate ->
        """
          <xhtml:link rel="alternate" hreflang="#{xml_escape(alternate.hreflang)}" href="#{xml_escape(alternate.href)}" />\
        """
      end)

    """
      <url>
        <loc>#{xml_escape(loc)}</loc>
    #{alternate_links}
      </url>\
    """
  end

  defp xml_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
