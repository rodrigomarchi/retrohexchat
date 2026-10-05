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
  bytes: the text of the lines the page will show — so a second edit of an
  already edited line still changes it — and the release, so a fix to how a
  page is drawn reaches a robot that already holds the old one.
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
  alias RetroHexChatWeb.ArchiveHTML
  alias RetroHexChatWeb.BuildInfo
  alias RetroHexChatWeb.SEO

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"channel" => slug}) do
    channel = channel_name(slug)

    case Archive.days_for(channel) do
      [] ->
        not_found(conn)

      days ->
        conn
        |> maybe_not_modified(etag_for([channel, days, BuildInfo.version()]))
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
  def day(conn, %{"channel" => slug, "date" => date} = params) do
    channel = channel_name(slug)

    with {:ok, cursor} <- cursor(params),
         %{page: %{items: [first | _] = entries} = page, previous: previous} <-
           Archive.page_for(channel, date, after: cursor) do
      day_path = "/archive/#{slug}/#{date}"

      conn
      |> maybe_not_modified(
        etag_for([
          channel,
          date,
          cursor,
          page.has_more,
          BuildInfo.version(),
          Enum.map(entries, &{&1.id, &1.text})
        ])
      )
      |> assign_page(channel, slug, path: page_path(day_path, cursor))
      |> assign(:entries, entries)
      |> assign(:date, date)
      |> assign(:prev_path, previous_path(day_path, previous))
      |> assign(:next_path, if(page.has_more, do: page_path(day_path, page.next_cursor)))
      |> assign_neighbour_urls()
      |> assign(:page_title, day_title(channel, date, cursor, first))
      |> assign(:page_description, description(channel, date, entries))
      |> render_cached(:day)
    else
      _ -> not_found(conn)
    end
  end

  # `after` is the id of the line the page follows. Anything that is not a
  # whole number is a URL nobody was ever given.
  defp cursor(%{"after" => value}) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> :error
    end
  end

  defp cursor(_params), do: {:ok, nil}

  defp page_path(day_path, nil), do: day_path
  defp page_path(day_path, cursor), do: "#{day_path}?after=#{cursor}"

  defp previous_path(_day_path, nil), do: nil
  defp previous_path(day_path, :start), do: day_path
  defp previous_path(day_path, cursor), do: page_path(day_path, cursor)

  defp assign_neighbour_urls(conn) do
    conn
    |> assign(:prev_url, conn.assigns.prev_path && SEO.site_url(conn.assigns.prev_path))
    |> assign(:next_url, conn.assigns.next_path && SEO.site_url(conn.assigns.next_path))
  end

  # Every page of a day is its own canonical, so each needs a title of its own:
  # a search result list of identical titles reads as one page repeated.
  defp day_title(channel, date, nil, _first), do: "#{page_title(channel)} — #{date}"

  defp day_title(channel, date, _cursor, first) do
    dgettext("landing", "%{title} — from %{time}",
      title: "#{page_title(channel)} — #{date}",
      time: ArchiveHTML.at(first.at)
    )
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
    # A line that is only an attachment has no text, and a description built
    # from it would be the channel name followed by a run of spaces. What a
    # search result shows is the words somebody wrote.
    opening =
      entries
      |> Enum.map(&String.trim(&1.text))
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")
      |> String.slice(0, 150)

    dgettext("landing", "%{channel} on %{date}: %{opening}",
      channel: channel,
      date: date,
      opening: opening
    )
  end
end
