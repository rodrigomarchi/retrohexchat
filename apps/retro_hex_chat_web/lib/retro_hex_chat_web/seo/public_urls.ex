defmodule RetroHexChatWeb.SEO.PublicUrls do
  @moduledoc """
  The public pages the site asks search engines to index, with the day each last changed.

  The sitemap renders these lists and IndexNow announces them, so what one
  offers is what the other reports. A `lastmod` is an ISO date, or `nil`
  whenever the day a page last changed is not knowable — a build with no git
  to ask. Neither consumer may guess one.
  """

  @behaviour RetroHexChat.SEO.IndexNow.UrlSource

  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.ContentDates
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.ShowcaseCatalog

  @type entry :: {path :: String.t(), lastmod :: String.t() | nil}

  @doc """
  The pages published in every language, by their unprefixed path: the landing
  pages, the game pages and the help. Each expands to one URL per locale.
  """
  @spec localized_paths([map()]) :: [entry()]
  def localized_paths(topics \\ HelpTopics.all_topics()) do
    help_topic_paths =
      topics
      |> Enum.reject(&(&1.id == "welcome"))
      |> Enum.map(&{"/chat/help/#{&1.id}", ContentDates.help_topic(&1.id)})

    landing_paths = Enum.map(SEO.landing_paths(), &{&1, ContentDates.landing(&1)})
    game_paths = Enum.map(GameCatalog.slugs(), &{"/games/#{&1}", ContentDates.game_page(&1)})

    (landing_paths ++
       game_paths ++ [{"/chat/help", ContentDates.help_topic("welcome")}] ++ help_topic_paths)
    |> Enum.uniq_by(&elem(&1, 0))
  end

  @doc "The showcase pages: English only, one URL each, and no known day."
  @spec showcase_paths() :: [String.t()]
  def showcase_paths, do: ShowcaseCatalog.paths()

  @doc """
  Every published archive page: each channel's index, dated by its most
  recent day, and each day's page, dated by the day it is. A conversation has
  no translated version, so these are one URL for every reader.
  """
  @spec archive_paths() :: [entry()]
  def archive_paths do
    for channel <- Archive.published_channels(),
        slug = archive_slug(channel),
        days = Archive.days_for(channel),
        entry <- [
          {"/archive/#{slug}", List.first(days)} | Enum.map(days, &{"/archive/#{slug}/#{&1}", &1})
        ] do
      entry
    end
  end

  @impl RetroHexChat.SEO.IndexNow.UrlSource
  @spec pages_changed_since(Date.t()) :: [String.t()]
  def pages_changed_since(%Date{} = since) do
    for {path, lastmod} <- localized_paths(),
        changed_since?(lastmod, since),
        url <- SEO.localized_urls(path) do
      url.href
    end
  end

  @impl RetroHexChat.SEO.IndexNow.UrlSource
  @spec archive_day(Date.t()) :: [String.t()]
  def archive_day(%Date{} = day) do
    iso = Date.to_iso8601(day)

    for channel <- Archive.published_channels(),
        iso in Archive.days_for(channel),
        slug = archive_slug(channel),
        path <- ["/archive/#{slug}", "/archive/#{slug}/#{iso}"] do
      SEO.site_url(path)
    end
  end

  @spec archive_slug(String.t()) :: String.t()
  defp archive_slug(channel), do: String.trim_leading(channel, "#")

  # A page with no known day is never "changed": announcing it on every boot
  # would announce the whole site on every deploy.
  @spec changed_since?(String.t() | nil, Date.t()) :: boolean()
  defp changed_since?(nil, _since), do: false

  defp changed_since?(lastmod, since) do
    case Date.from_iso8601(String.slice(lastmod, 0, 10)) do
      {:ok, day} -> Date.compare(day, since) != :lt
      {:error, _reason} -> false
    end
  end
end
