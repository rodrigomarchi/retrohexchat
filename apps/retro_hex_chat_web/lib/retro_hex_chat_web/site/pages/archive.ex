defmodule RetroHexChatWeb.Site.Pages.Archive do
  @moduledoc """
  The only part of a conversation a stranger can read: a channel's published
  days, and one day's lines, a page at a time.

  It opens in a document window of its own over the chat, so whoever arrives
  from a search lands on the same desktop the conversation is still going on
  in. What it shows — and when it answers nothing at all — is
  `RetroHexChat.Chat.Archive`'s decision:

  **Nothing is cached between requests.** Turning the archive off, deleting a
  line, making a channel secret — each has to take the page down on the next
  request. `RetroHexChatWeb.Plugs.ArchiveConditional` answers a robot that
  already holds a page with a `304` before anything renders, from an `etag`
  derived from the **data** (`etag/1`): the lines' text and the release, never
  the rendered bytes, which carry a fresh CSRF token on every request.

  A channel that does not publish answers **404, never 403**: the second would
  confirm the channel exists, and for a room that never agreed to be public
  that confirmation is itself the leak.

  The canonical is the unprefixed URL under every locale, with no hreflang
  alternates: a conversation has no translated version.
  """
  use RetroHexChatWeb.Site.Page

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  alias RetroHexChat.Chat.Archive
  alias RetroHexChatWeb.BuildInfo
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def slot, do: :archive

  @doc """
  What an archive address shows, or `:not_found`. Shared with the conditional
  plug, which needs the same data to name the page's `etag` before rendering.
  """
  @spec data(map()) :: {:ok, map()} | :not_found
  def data(%{"channel" => slug, "date" => date} = params) do
    channel = channel_name(slug)

    with {:ok, cursor} <- cursor(params),
         %{page: %{items: [first | _] = entries} = page, previous: previous} <-
           Archive.page_for(channel, date, after: cursor) do
      day_path = "/archive/#{slug}/#{date}"

      {:ok,
       %{
         kind: :day,
         channel: channel,
         slug: slug,
         date: date,
         cursor: cursor,
         first: first,
         entries: entries,
         has_more: page.has_more,
         path: page_path(day_path, cursor),
         prev_path: previous_path(day_path, previous),
         next_path: if(page.has_more, do: page_path(day_path, page.next_cursor))
       }}
    else
      _ -> :not_found
    end
  end

  def data(%{"channel" => slug}) do
    channel = channel_name(slug)

    case Archive.days_for(channel) do
      [] ->
        :not_found

      days ->
        {:ok, %{kind: :index, channel: channel, slug: slug, days: days, path: "/archive/#{slug}"}}
    end
  end

  @doc """
  The `etag` of what `data/1` returned: the text of the lines a page shows —
  so a second edit of an already edited line still changes it — and the
  release, so a fix to how a page is drawn reaches a robot that holds the old one.
  """
  @spec etag(map()) :: String.t()
  def etag(%{kind: :index} = data), do: hash([data.channel, data.days, BuildInfo.version()])

  def etag(%{kind: :day} = data) do
    hash([
      data.channel,
      data.date,
      data.cursor,
      data.has_more,
      BuildInfo.version(),
      Enum.map(data.entries, &{&1.id, &1.text})
    ])
  end

  @impl RetroHexChatWeb.Site.Page
  def load(params, _ctx) do
    case data(params) do
      {:ok, data} -> {:ok, page(data)}
      :not_found -> :not_found
    end
  end

  defp page(%{kind: :index} = data) do
    data
    |> common()
    |> Map.merge(%{
      page_title: page_title(data.channel),
      page_description:
        dgettext(
          "landing",
          "Everything said in %{channel} since it opened its archive, one page per day.",
          channel: data.channel
        )
    })
  end

  defp page(%{kind: :day} = data) do
    data
    |> common()
    |> Map.merge(%{
      prev_url: data.prev_path && SEO.site_url(data.prev_path),
      next_url: data.next_path && SEO.site_url(data.next_path),
      page_title: day_title(data.channel, data.date, data.cursor, data.first),
      page_description: description(data.channel, data.date, data.entries)
    })
  end

  defp common(data) do
    Map.merge(data, %{
      window_title: data.channel,
      window_icon: :icon_channels,
      canonical_path: data.path,
      canonical_url: SEO.site_url(data.path),
      hreflang_alternates: false,
      robots: "index, follow",
      windows: [
        %{
          id: if(data.kind == :day, do: "archive-day", else: "archive-index"),
          label: data.channel,
          icon: :icon_channels
        }
      ]
    })
  end

  embed_templates "archive_*"

  @impl RetroHexChatWeb.Site.Page
  def render(%{kind: :index} = assigns), do: archive_index(assigns)
  def render(%{kind: :day} = assigns), do: archive_day(assigns)

  @doc "The day a reader is most likely to want: the newest one."
  @spec newest_day([String.t()]) :: String.t() | nil
  def newest_day([day | _rest]), do: day
  def newest_day(_days), do: nil

  @doc "`14:03` in UTC — the archive has no reader whose zone it could know."
  @spec at(DateTime.t()) :: String.t()
  def at(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_time()
    |> Calendar.strftime("%H:%M")
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

  # Every page of a day is its own canonical, so each needs a title of its own:
  # a search result list of identical titles reads as one page repeated.
  defp day_title(channel, date, nil, _first), do: "#{page_title(channel)} — #{date}"

  defp day_title(channel, date, _cursor, first) do
    dgettext("landing", "%{title} — from %{time}",
      title: "#{page_title(channel)} — #{date}",
      time: at(first.at)
    )
  end

  defp hash(parts) do
    hash =
      :sha256
      |> :crypto.hash(:erlang.term_to_binary(parts))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    ~s(W/"#{hash}")
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
