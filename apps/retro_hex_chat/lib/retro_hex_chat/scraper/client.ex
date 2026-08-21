defmodule RetroHexChat.Scraper.Client do
  @moduledoc """
  How the scraper gets a page from the open internet.

  Injected rather than called directly, for the same reason the RSS feed fetcher
  is: the interesting behaviour is what happens *after* the bytes arrive — a page
  stored once and served to every consumer, an expired row revalidated, a failure
  told apart from a blip — and none of that should need the internet to be tested.

  One callback, on purpose. The behaviour it replaces had three overlapping ones
  (`fetch_title/1`, `fetch_metadata/1` and an optional `fetch_title_result/1`
  dispatched through `function_exported?/3`), which meant a stub could satisfy the
  compiler and still miss the entry point production used.
  """

  alias RetroHexChat.Scraper.ScrapedPage

  @typedoc """
  Everything one visit to a page produced.

  `metadata` carries the publisher's own preview fields, **unescaped**; the rest
  is what the transfer itself revealed, and is what makes the next visit cheap
  (`etag`, `last_modified`) or unnecessary (`http_status`).
  """
  @type scrape :: %{
          required(:metadata) => metadata(),
          required(:final_url) => String.t(),
          optional(:http_status) => pos_integer(),
          optional(:content_type) => String.t() | nil,
          optional(:etag) => String.t() | nil,
          optional(:last_modified) => String.t() | nil,
          optional(:excerpt) => String.t() | nil,
          optional(:image_alt) => String.t() | nil,
          optional(:author) => String.t() | nil,
          optional(:published_at) => DateTime.t() | nil,
          optional(:modified_at) => DateTime.t() | nil,
          optional(:lang) => String.t() | nil,
          optional(:section) => String.t() | nil,
          optional(:tags) => [String.t()],
          optional(:content_text) => String.t() | nil,
          optional(:content_text_truncated) => boolean(),
          optional(:content_word_count) => non_neg_integer() | nil,
          optional(:raw_metadata) => map()
        }

  @type metadata :: %{
          optional(:title) => String.t() | nil,
          optional(:description) => String.t() | nil,
          optional(:image) => String.t() | nil,
          optional(:image_alt) => String.t() | nil,
          optional(:url) => String.t() | nil,
          optional(:site_name) => String.t() | nil,
          optional(:author) => String.t() | nil,
          optional(:published_at) => DateTime.t() | nil,
          optional(:modified_at) => DateTime.t() | nil,
          optional(:section) => String.t() | nil,
          optional(:tags) => [String.t()],
          optional(:word_count) => non_neg_integer() | nil
        }

  @type error :: atom() | {:http_status, pos_integer()} | term()

  @typedoc """
  Per-visit options.

  `:if_none_match` and `:if_modified_since` come straight off a stored row, so an
  expired page can be renewed by a `304` instead of a download.

  """
  @type opts :: [if_none_match: String.t() | nil, if_modified_since: String.t() | nil]

  @doc "Visit `url`, or learn that it has not changed since it was last visited."
  @callback scrape(url :: String.t(), opts()) ::
              {:ok, scrape()} | {:not_modified} | {:error, error()}

  @doc "The client in force. Configure `:page_scraper` to substitute one."
  @spec impl() :: module()
  def impl do
    Application.get_env(:retro_hex_chat, :page_scraper, RetroHexChat.Scraper.HTTP)
  end

  @doc """
  Flattens a scrape into the columns a `ScrapedPage` stores.

  Lives here rather than in the store because it is the shape of what a *client*
  returns; a different client with a different upstream still lands in the same
  columns.
  """
  @spec to_page_attrs(scrape()) :: map()
  def to_page_attrs(scrape) do
    metadata = Map.get(scrape, :metadata) || %{}

    %{
      title: metadata[:title],
      description: metadata[:description],
      excerpt: Map.get(scrape, :excerpt),
      image_url: metadata[:image],
      image_alt: metadata[:image_alt] || Map.get(scrape, :image_alt),
      canonical_url: metadata[:url],
      site_name: metadata[:site_name],
      final_url: Map.get(scrape, :final_url),
      http_status: Map.get(scrape, :http_status),
      content_type: Map.get(scrape, :content_type),
      etag: Map.get(scrape, :etag),
      last_modified: Map.get(scrape, :last_modified),
      author: Map.get(scrape, :author),
      published_at: Map.get(scrape, :published_at),
      modified_at: Map.get(scrape, :modified_at),
      lang: Map.get(scrape, :lang),
      section: Map.get(scrape, :section),
      tags: Map.get(scrape, :tags) || [],
      content_text: Map.get(scrape, :content_text),
      content_text_truncated: Map.get(scrape, :content_text_truncated, false),
      content_word_count: Map.get(scrape, :content_word_count),
      raw_metadata: Map.get(scrape, :raw_metadata) || %{}
    }
  end

  @doc """
  Rebuilds the loose metadata map a renderer expects from a stored row.

  The inverse of `to_page_attrs/1`, and the reason consumers did not have to
  change shape when they stopped fetching for themselves.
  """
  @spec to_metadata(ScrapedPage.t()) :: metadata()
  def to_metadata(%ScrapedPage{} = page) do
    %{
      title: page.title,
      description: page.description || page.excerpt,
      image: page.image_url,
      image_alt: page.image_alt,
      url: page.canonical_url,
      site_name: page.site_name,
      author: byline(page.author),
      published_at: page.published_at,
      modified_at: page.modified_at,
      section: page.section,
      tags: tags(page.tags),
      word_count: page.content_word_count || word_count(page.content_text)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  @max_byline_length 60

  @doc """
  An author string only if it reads as a person's name.

  Publishers put anything in the author slot: BBC writes a Facebook page URL into
  `article:author`, WordPress sites emit the JSON-LD `@id` of the author node, and
  plenty just leave a handle. A URL under a headline reads as a broken card, so
  anything URL-shaped is dropped rather than shown.

  Applied both when a page is read and when a stored row is rendered, because the
  archive holds rows for four months and already contains what the old extractor
  let through.
  """
  @spec byline(String.t() | nil) :: String.t() | nil
  def byline(author) when is_binary(author) do
    author = String.trim(author)

    cond do
      author == "" -> nil
      String.contains?(author, "://") -> nil
      String.contains?(author, "/") -> nil
      String.length(author) > @max_byline_length -> nil
      true -> author
    end
  end

  def byline(_author), do: nil

  @spec tags([String.t()] | nil) :: [String.t()] | nil
  defp tags(tags) when is_list(tags) do
    case Enum.reject(tags, &(not is_binary(&1) or String.trim(&1) == "")) do
      [] -> nil
      present -> present
    end
  end

  defp tags(_tags), do: nil

  # Derived on read rather than stored. Counting words costs a `String.split/1`
  # over a few kilobytes for the one to five items a poll actually renders, while
  # a column would need a `scraper_version` bump to backfill — and rows renewed by
  # a `304` never re-extract, so the column would stay empty on exactly the pages
  # that are still being read.
  @spec word_count(String.t() | nil) :: non_neg_integer() | nil
  defp word_count(text) when is_binary(text) and text != "" do
    text |> String.split() |> length()
  end

  defp word_count(_text), do: nil
end
