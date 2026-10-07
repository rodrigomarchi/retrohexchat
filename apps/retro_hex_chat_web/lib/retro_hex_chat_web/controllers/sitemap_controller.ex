defmodule RetroHexChatWeb.SitemapController do
  @moduledoc """
  Serves `/sitemap.xml` with all landing page and help topic URLs for search engine indexing.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.SEO.PublicUrls

  @cache_key {__MODULE__, :sitemaps}
  # Paths, not URLs: each one expands to fourteen localized URLs carrying
  # fifteen alternates each. At five the index named sixty-one chunks of
  # seventy URLs, and at five hundred it named one file of eight megabytes.
  # A hundred paths is about fourteen hundred URLs and two megabytes — well
  # inside the protocol's fifty, and small enough that a failed fetch retries
  # two megabytes rather than eight.
  @chunk_size 100
  # A showcase entry is one URL, not one per locale, so far more fit per file.
  @showcase_chunk_size 50
  @archive_chunk "archive.xml"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    send_xml(conn, sitemaps().index)
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # The archive chunk is built per request while every other chunk is built
  # once. It has to be: a channel publishes a new day every day it is used, and
  # turning the archive off has to remove the pages from here too. A chunk
  # cached in `:persistent_term` would keep offering a page that stopped
  # answering, which is the one failure this feature cannot have.
  def show(conn, %{"name" => @archive_chunk}) do
    send_xml(conn, xml_resource(build_archive_urlset()))
  end

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
      chunks(PublicUrls.localized_paths(topics), "public", @chunk_size, &build_urlset/1) ++
        chunks(
          PublicUrls.showcase_paths(),
          "showcase",
          @showcase_chunk_size,
          &build_canonical_urlset/1
        )

    # The archive's name is in the index but its body is not built here: the
    # index is a list of names and those do not change, while what the archive
    # chunk contains changes every day.
    names = Enum.map(chunk_entries, &elem(&1, 0)) ++ [@archive_chunk]

    %{
      index: names |> build_sitemap_index() |> xml_resource(),
      chunks: Map.new(chunk_entries)
    }
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

  # One canonical URL per archived day, and no hreflang at all: a conversation
  # has no translated version, so the archive's pages are the same URL for
  # every reader.
  defp build_archive_urlset, do: build_canonical_urlset(PublicUrls.archive_paths())

  # One canonical URL per path, no hreflang: the showcase ships in English only.
  defp build_canonical_urlset(entries) do
    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n),
      Enum.map(entries, fn
        {path, lastmod} -> url_entry(SEO.site_url(path), [], lastmod)
        path -> url_entry(SEO.site_url(path), [])
      end),
      "</urlset>\n"
    ]
    |> IO.iodata_to_binary()
  end

  defp localized_url_entries({path, lastmod}) do
    alternate_links =
      path
      |> SEO.alternate_links()
      |> Enum.map(&alternate_link/1)

    path
    |> SEO.localized_urls()
    |> Enum.map(&url_entry(&1.href, alternate_links, lastmod))
  end

  defp url_entry(loc, alternate_links, lastmod \\ nil) do
    [
      "  <url>\n",
      "    <loc>",
      xml_escape(loc),
      "</loc>\n",
      lastmod_element(lastmod),
      alternate_links,
      "  </url>\n"
    ]
  end

  defp lastmod_element(nil), do: []

  defp lastmod_element(lastmod),
    do: ["    <lastmod>", xml_escape(lastmod), "</lastmod>\n"]

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
