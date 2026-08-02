defmodule RetroHexChatWeb.SitemapController do
  @moduledoc """
  Serves `/sitemap.xml` with all landing page and help topic URLs for search engine indexing.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.ShowcaseCatalog

  @cache_key {__MODULE__, :sitemaps}
  @chunk_size 5
  # A showcase entry is one URL, not one per locale, so far more fit per file.
  @showcase_chunk_size 50

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    send_xml(conn, sitemaps().index)
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"name" => name}) do
    case Map.fetch(sitemaps().chunks, name) do
      {:ok, xml} -> send_xml(conn, xml)
      :error -> send_resp(conn, 404, "Not found")
    end
  end

  defp send_xml(conn, xml) do
    conn =
      conn
      |> put_resp_content_type("application/xml")
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> put_resp_header("etag", xml.etag)
      |> put_resp_header("vary", "accept-encoding")

    if etag_matches?(conn, xml.etag) do
      send_resp(conn, 304, "")
    else
      {conn, body} = maybe_gzip(conn, xml)

      send_resp(conn, 200, body)
    end
  end

  defp maybe_gzip(conn, xml) do
    if accepts_gzip?(conn) do
      {put_resp_header(conn, "content-encoding", "gzip"), xml.gzip_body}
    else
      {conn, xml.body}
    end
  end

  defp accepts_gzip?(conn) do
    conn
    |> get_req_header("accept-encoding")
    |> Enum.any?(&(&1 |> String.downcase() |> String.contains?("gzip")))
  end

  defp etag_matches?(conn, etag) do
    conn
    |> get_req_header("if-none-match")
    |> Enum.any?(fn header ->
      header
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.any?(&(&1 in ["*", etag]))
    end)
  end

  defp xml_resource(body) do
    hash =
      body
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    %{body: body, gzip_body: :zlib.gzip(body), etag: ~s(W/"#{hash}")}
  end

  @spec build_sitemaps([map()]) :: %{index: map(), chunks: %{String.t() => map()}}
  defp build_sitemaps(topics) do
    chunk_entries =
      chunks(sitemap_paths(topics), "public", @chunk_size, &build_urlset/1) ++
        chunks(
          ShowcaseCatalog.paths(),
          "showcase",
          @showcase_chunk_size,
          &build_canonical_urlset/1
        )

    %{
      index: chunk_entries |> Enum.map(&elem(&1, 0)) |> build_sitemap_index() |> xml_resource(),
      chunks: Map.new(chunk_entries)
    }
  end

  defp sitemap_paths(topics) do
    help_topic_paths =
      topics
      |> Enum.reject(&(&1.id == "welcome"))
      |> Enum.map(&"/chat/help/#{&1.id}")

    (SEO.landing_paths() ++ ["/chat/help"] ++ help_topic_paths)
    |> Enum.uniq()
  end

  defp chunks(paths, prefix, size, builder) do
    paths
    |> Enum.chunk_every(size)
    |> Enum.with_index(1)
    |> Enum.map(fn {chunk, index} ->
      {"#{prefix}-#{index}.xml", chunk |> builder.() |> xml_resource()}
    end)
  end

  defp build_sitemap_index(chunk_names) do
    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n),
      Enum.map(chunk_names, &sitemap_index_entry/1),
      "</sitemapindex>\n"
    ]
    |> IO.iodata_to_binary()
  end

  defp sitemap_index_entry(name) do
    [
      "  <sitemap>\n",
      "    <loc>",
      xml_escape(SEO.site_url("/sitemaps/#{name}")),
      "</loc>\n",
      "  </sitemap>\n"
    ]
  end

  defp build_urlset(paths) do
    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n),
      Enum.map(paths, &localized_url_entries/1),
      "</urlset>\n"
    ]
    |> IO.iodata_to_binary()
  end

  # One canonical URL per path, no hreflang: the showcase ships in English only.
  defp build_canonical_urlset(paths) do
    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n),
      Enum.map(paths, &url_entry(SEO.site_url(&1), [])),
      "</urlset>\n"
    ]
    |> IO.iodata_to_binary()
  end

  defp localized_url_entries(path) do
    alternate_links =
      path
      |> SEO.alternate_links()
      |> Enum.map(&alternate_link/1)

    path
    |> SEO.localized_urls()
    |> Enum.map(&url_entry(&1.href, alternate_links))
  end

  defp url_entry(loc, alternate_links) do
    [
      "  <url>\n",
      "    <loc>",
      xml_escape(loc),
      "</loc>\n",
      alternate_links,
      "  </url>\n"
    ]
  end

  defp alternate_link(alternate) do
    [
      ~s(    <xhtml:link rel="alternate" hreflang="),
      xml_escape(alternate.hreflang),
      ~s(" href="),
      xml_escape(alternate.href),
      ~s(" />\n)
    ]
  end

  defp sitemaps do
    case :persistent_term.get(@cache_key, nil) do
      nil ->
        sitemaps = HelpTopics.all_topics() |> build_sitemaps()
        :persistent_term.put(@cache_key, sitemaps)
        sitemaps

      sitemaps ->
        sitemaps
    end
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
