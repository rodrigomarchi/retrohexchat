defmodule RetroHexChatWeb.ArchiveController do
  @moduledoc """
  The only page of this product a stranger can read.

  A controller rather than a LiveView, which is a deliberate departure from the
  plan that named an `ArchiveLive`. Nothing on this page moves: it is text that
  was said in the past, and a LiveView would open a socket to render it. What
  the page does need is the thing a LiveView route cannot give it — an `etag`
  and a `304`, because these pages exist to be swept by robots and a robot that
  can revalidate cheaply sweeps more of them.

  **Nothing is cached between requests.** `SitemapController` builds its bodies
  once and keeps them in `:persistent_term`; this one must not. Turning the
  archive off, deleting a line, making a channel secret — each has to take the
  page down on the next request, and a cached body would keep answering after
  the decision that withdrew it.

  For the same reason the pages carry `max-age=0, must-revalidate` rather than
  a lifetime. A cache holding one for even five minutes keeps serving a page
  that a founder has withdrawn, and the browser proved it: a reader who loaded
  a day and came back after the switch was flipped was handed the page again,
  out of its own cache, with the server never consulted. Revalidation costs a
  robot nothing — the `etag` answers `304` — and it is the only setting under
  which switching off actually switches off.

  The `etag` is therefore computed from the **data**, not from the rendered
  bytes: the lines the page will show and the state that changes how they read.
  Hashing the document was the first attempt and it never matched twice — the
  layout carries a fresh CSRF token on every request, so every render differed
  and no robot could ever have revalidated anything. Deriving it from the
  content also lets a match answer before rendering at all, which is the whole
  point of offering one.

  A channel that does not publish answers **404, never 403**. The second would
  confirm that the channel exists, and for a room that never agreed to be
  public that confirmation is itself the leak.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.Archive
  alias RetroHexChatWeb.SEO

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"channel" => slug}) do
    channel = channel_name(slug)

    case Archive.days_for(channel) do
      [] ->
        not_found(conn)

      days ->
        conn
        |> maybe_not_modified(etag_for([channel, days]))
        |> assign_page(channel, slug, path: "/archive/#{slug}")
        |> assign(:days, days)
        |> assign(:page_title, page_title(channel))
        |> assign(
          :page_description,
          dgettext(
            "landing",
            "Everything said in %{channel} since it opened its archive, one page per day.",
            channel: channel
          )
        )
        |> render_cached(:index)
    end
  end

  @spec day(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def day(conn, %{"channel" => slug, "date" => date}) do
    channel = channel_name(slug)

    case Archive.messages_for(channel, date) do
      [] ->
        not_found(conn)

      entries ->
        conn
        |> maybe_not_modified(etag_for([channel, date, Enum.map(entries, &{&1.id, &1.edited?})]))
        |> assign_page(channel, slug, path: "/archive/#{slug}/#{date}")
        |> assign(:entries, entries)
        |> assign(:date, date)
        |> assign(:days, Archive.days_for(channel))
        |> assign(:page_title, "#{page_title(channel)} — #{date}")
        |> assign(:page_description, description(channel, date, entries))
        |> render_cached(:day)
    end
  end

  # The canonical is the unprefixed URL under every locale, and the layout is
  # told to emit no hreflang alternates at all: a conversation has no
  # translated version, so claiming one would point a search engine at the
  # same page thirteen times.
  defp assign_page(conn, channel, slug, path: path) do
    conn
    |> assign(:channel, channel)
    |> assign(:slug, slug)
    |> assign(:canonical_path, path)
    |> assign(:canonical_url, SEO.site_url(path))
    |> assign(:hreflang_alternates, false)
    |> assign(:robots, "index, follow")
    |> assign(:windows, [
      %{id: window_id(path), label: channel, icon: :icon_channels}
    ])
  end

  defp window_id("/archive/" <> rest) do
    if String.contains?(rest, "/"), do: "archive-day", else: "archive-index"
  end

  # The etag is decided before anything is rendered, so a robot that already has
  # the day is answered without touching the templates. `halted` carries the
  # decision past the two `assign` chains rather than duplicating them.
  defp maybe_not_modified(conn, etag) do
    conn = put_resp_header(conn, "etag", etag)

    if etag_matches?(conn, etag) do
      conn
      |> put_resp_header("cache-control", "public, max-age=0, must-revalidate")
      |> send_resp(304, "")
      |> halt()
    else
      conn
    end
  end

  defp render_cached(%Plug.Conn{halted: true} = conn, _template), do: conn

  defp render_cached(conn, template) do
    conn
    |> put_resp_header("cache-control", "public, max-age=0, must-revalidate")
    |> put_resp_header("vary", "accept-encoding")
    |> register_before_send(&maybe_gzip/1)
    |> render(template)
  end

  defp maybe_gzip(conn) do
    if accepts_gzip?(conn) do
      conn
      |> put_resp_header("content-encoding", "gzip")
      |> Map.put(:resp_body, :zlib.gzip(conn.resp_body))
    else
      conn
    end
  end

  defp etag_for(parts) do
    hash =
      :sha256
      |> :crypto.hash(:erlang.term_to_binary(parts))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    ~s(W/"#{hash}")
  end

  defp accepts_gzip?(conn) do
    conn
    |> get_req_header("accept-encoding")
    |> Enum.any?(&(&1 |> String.downcase() |> String.contains?("gzip")))
  end

  defp etag_matches?(conn, etag) do
    conn
    |> get_req_header("if-none-match")
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&String.trim/1)
    |> Enum.any?(&(&1 in ["*", etag]))
  end

  defp not_found(conn) do
    conn
    |> put_status(404)
    |> put_resp_content_type("text/html")
    |> send_resp(404, "")
  end

  # A URL cannot carry the `#`: everything after it belongs to the browser.
  defp channel_name("#" <> _rest = name), do: name
  defp channel_name(slug) when is_binary(slug), do: "#" <> slug

  defp page_title(channel) do
    dgettext("landing", "%{channel} archive", channel: channel)
  end

  defp description(channel, date, entries) do
    opening =
      entries
      |> Enum.map(& &1.text)
      |> Enum.join(" ")
      |> String.slice(0, 150)

    dgettext("landing", "%{channel} on %{date}: %{opening}",
      channel: channel,
      date: date,
      opening: opening
    )
  end
end
