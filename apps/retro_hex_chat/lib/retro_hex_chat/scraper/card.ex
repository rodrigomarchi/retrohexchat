defmodule RetroHexChat.Scraper.Card do
  @moduledoc """
  One scraped page, as one Markdown card.

  This is the house style for a link anywhere in the product — the RSS bot's feed
  items and a URL somebody pasted into a channel render through the same function,
  so they cannot drift apart. It used to live inside the RSS capability, which
  made the bot the owner of a format the whole chat needed.

  Markdown rather than markup on purpose: the chat already renders Markdown for
  bot messages, through a sanitiser that hardens images, so a card needs no
  privileged rendering path of its own.

  Callers that have more context than the page supply it as options —
  `:fallback_title` and `:fallback_source` for a feed item whose publisher's page
  is thin, `:url` for the address to link when the page names no canonical one.
  """
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Scraper.Client
  alias RetroHexChat.Scraper.ScrapedPage

  @source_limit 48
  @headline_limit 180
  @description_limit 360
  @message_url_limit 400
  @message_limit 1_000

  @type opts :: [
          fallback_title: String.t() | nil,
          fallback_source: String.t() | nil,
          url: String.t() | nil,
          image_policy: :any | :cached
        ]

  @doc """
  The card, or `nil` when there is nothing worth showing.

  A page with no title is not a thin card, it is no card: a link whose page
  refused to say what it was should read as a plain link. Callers that must
  always produce something — a feed item is a message on its own — pass a
  `:fallback_title` they are willing to print.
  """
  @spec markdown(ScrapedPage.t() | Client.metadata(), opts()) :: String.t() | nil
  def markdown(page_or_metadata, opts \\ [])

  def markdown(%ScrapedPage{} = page, opts) do
    page
    |> Client.to_metadata()
    |> markdown(Keyword.put_new(opts, :url, page.url))
  end

  def markdown(metadata, opts) when is_map(metadata) do
    url = card_url(metadata, opts[:url])
    source = card_source(metadata, opts[:fallback_source], url)

    case card_title(metadata, opts[:fallback_title], source) do
      nil ->
        nil

      title ->
        [
          card_header(source, title),
          card_byline(metadata),
          card_image_markdown(
            card_image(metadata, opts[:image_policy] || :any),
            metadata,
            source
          ),
          card_quote(card_description(metadata)),
          card_story_link(url)
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n\n")
        |> fit_message()
    end
  end

  def markdown(_metadata, _opts), do: nil

  # Publishers put their whole positioning statement in the feed title —
  # "cs.LG updates on arXiv.org", "Phys.org - latest science and technology news
  # stories", "Al Jazeera – Breaking News, World News and Video". As a label
  # repeated on every line that is noise, and truncating it lands mid-sentence.
  # The part before the first separator is the name; the rest is the tagline.
  @label_separators [" updates on ", " - ", " – ", " — ", " | ", ": "]

  @doc "The publication's name, taken out of whatever prose surrounds it."
  @spec source_label(String.t()) :: String.t()
  def source_label(title) when is_binary(title) do
    title = collapse_space(title)

    Enum.reduce(@label_separators, title, fn separator, current ->
      case String.split(current, separator, parts: 2) do
        [head, _tail] when head != "" -> head
        _ -> current
      end
    end)
  end

  # The publisher's own name if it gives one, the caller's if it knows better,
  # and otherwise the host. A link somebody pasted has no feed behind it to name
  # it, and "example.com" is what a reader would have read off the address bar —
  # far better than a card that labels every pasted link with the same word.
  @spec card_source(Client.metadata(), String.t() | nil, String.t() | nil) :: String.t() | nil
  defp card_source(metadata, fallback_source, url) do
    case present(metadata[:site_name]) || present(fallback_source) || host_label(url) do
      nil -> nil
      source -> source |> collapse_space() |> truncate(@source_limit)
    end
  end

  # A field a publisher left blank is a field a publisher did not fill in. Both
  # reach here as `""` rather than `nil` — the store keeps what it was given —
  # and `"" || fallback` is `""` in Elixir, so without this an empty `<title>`
  # would win over a caller's perfectly good one and suppress the whole card.
  @spec present(String.t() | nil) :: String.t() | nil
  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil

  @spec host_label(String.t() | nil) :: String.t() | nil
  defp host_label(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" ->
        String.replace_prefix(host, "www.", "")

      _ ->
        nil
    end
  end

  defp host_label(_url), do: nil

  @spec card_title(Client.metadata(), String.t() | nil, String.t() | nil) :: String.t() | nil
  defp card_title(metadata, fallback_title, source) do
    case present(metadata[:title]) || present(fallback_title) do
      nil ->
        nil

      title ->
        title
        |> collapse_space()
        |> strip_source(source)
        |> truncate(@headline_limit)
    end
  end

  # Publishers append their own name to the `<title>` — "Corals Spin Tiny
  # Vortices | Quanta Magazine", "Sony might be rebooting… - Engadget" — and a
  # few prepend it. The card already carries the source as its label, so leaving
  # it in prints the publication twice on nearly a third of every batch.
  @spec strip_source(String.t(), String.t()) :: String.t()
  defp strip_source(title, source) when source in ["", nil], do: title

  defp strip_source(title, source) do
    Enum.reduce(@label_separators, title, fn separator, current ->
      current
      |> strip_suffix(separator <> source)
      |> strip_prefix(source <> separator)
    end)
  end

  @spec strip_suffix(String.t(), String.t()) :: String.t()
  defp strip_suffix(text, tail) do
    if suffix?(text, tail) and String.length(text) > String.length(tail) do
      text |> String.slice(0, String.length(text) - String.length(tail)) |> String.trim()
    else
      text
    end
  end

  @spec strip_prefix(String.t(), String.t()) :: String.t()
  defp strip_prefix(text, head) do
    if prefix?(text, head) and String.length(text) > String.length(head) do
      text |> String.slice(String.length(head)..-1//1) |> String.trim()
    else
      text
    end
  end

  @spec suffix?(String.t(), String.t()) :: boolean()
  defp suffix?(text, tail), do: String.ends_with?(String.downcase(text), String.downcase(tail))

  @spec prefix?(String.t(), String.t()) :: boolean()
  defp prefix?(text, head), do: String.starts_with?(String.downcase(text), String.downcase(head))

  # Who wrote it, when, and how long it takes to read. Omitted entirely when none
  # of the three is known, so a page that offers nothing produces exactly the card
  # it produced before. In practice the reading time is always available — it is
  # counted from the article's own text — so the line survives even when a
  # publisher names neither author nor date.
  @spec card_byline(Client.metadata()) :: String.t() | nil
  defp card_byline(metadata) do
    [
      metadata[:author],
      published_ago(metadata[:published_at]),
      reading_time(metadata[:word_count])
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      parts -> "_" <> (parts |> Enum.map(&markdown_escape/1) |> Enum.join(" · ")) <> "_"
    end
  end

  # Relative while it still reads as news, absolute once it does not. A publisher
  # with a clock ahead of ours would otherwise say "in 3 hours", so anything in
  # the future is treated as undated.
  @spec published_ago(DateTime.t() | nil) :: String.t() | nil
  defp published_ago(%DateTime{} = published_at) do
    seconds = DateTime.diff(DateTime.utc_now(), published_at, :second)

    cond do
      seconds < 0 -> nil
      seconds < 3600 -> dgettext("bots", "%{count}m ago", count: max(div(seconds, 60), 1))
      seconds < 86_400 -> dgettext("bots", "%{count}h ago", count: div(seconds, 3600))
      seconds < 30 * 86_400 -> dgettext("bots", "%{count}d ago", count: div(seconds, 86_400))
      true -> Calendar.strftime(published_at, "%d %b %Y")
    end
  end

  defp published_ago(_published_at), do: nil

  # An average adult reads prose at roughly 200 words a minute. Below a short
  # floor the number says nothing useful — a stub page is not "1 min read", it is
  # a page with no article on it.
  @words_per_minute 200
  @min_words_for_reading_time 60

  @spec reading_time(non_neg_integer() | nil) :: String.t() | nil
  defp reading_time(words) when is_integer(words) and words >= @min_words_for_reading_time do
    dgettext("bots", "%{count} min read", count: max(div(words, @words_per_minute), 1))
  end

  defp reading_time(_words), do: nil

  @spec card_url(Client.metadata(), String.t() | nil) :: String.t() | nil
  defp card_url(metadata, fallback_url) do
    Enum.find([metadata[:url], fallback_url], &linkable_url?/1)
  end

  @spec card_image(Client.metadata(), :any | :cached) :: String.t() | nil
  defp card_image(%{cached_image: image}, :cached)
       when is_binary(image) and byte_size(image) > 0 do
    if String.length(image) <= @message_url_limit and linkable_url?(image), do: image
  end

  defp card_image(_metadata, :cached), do: nil

  defp card_image(metadata, _policy) do
    Enum.find_value([metadata[:cached_image], metadata[:image]], fn image ->
      if is_binary(image) and
           byte_size(image) > 0 and
           String.length(image) <= @message_url_limit and
           linkable_url?(image) do
        image
      end
    end)
  end

  @spec card_description(Client.metadata()) :: String.t() | nil
  defp card_description(%{description: description})
       when is_binary(description) and byte_size(description) > 0 do
    description
    |> collapse_space()
    |> truncate(@description_limit)
  end

  defp card_description(_metadata), do: nil

  @spec card_header(String.t() | nil, String.t()) :: String.t()
  defp card_header(nil, title), do: markdown_escape(title)

  defp card_header(source, title) do
    source = markdown_escape(source)
    title = markdown_escape(title)

    "**#{source}** | #{title}"
  end

  @spec card_image_markdown(String.t() | nil, Client.metadata(), String.t() | nil) ::
          String.t() | nil
  defp card_image_markdown(nil, _metadata, _source), do: nil

  defp card_image_markdown(image, metadata, source) do
    "![#{card_image_alt(metadata, source)}](<#{markdown_url(image)}>)"
  end

  @spec card_quote(String.t() | nil) :: String.t() | nil
  defp card_quote(nil), do: nil
  defp card_quote(description), do: "> " <> markdown_escape(description)

  @spec card_story_link(String.t() | nil) :: String.t() | nil
  defp card_story_link(url) when is_binary(url) do
    if linkable_url?(url) and String.length(url) <= @message_url_limit do
      "[#{dgettext("bots", "Read full story")}](<#{markdown_url(url)}>)"
    end
  end

  defp card_story_link(_url), do: nil

  @spec linkable_url?(String.t() | nil) :: boolean()
  defp linkable_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ~w(http https) and is_binary(host) -> true
      _ -> false
    end
  end

  defp linkable_url?(_url), do: false

  @spec markdown_escape(String.t()) :: String.t()
  defp markdown_escape(text) do
    Regex.replace(~r/([\\`*_{}\[\]()#+\-.!|>])/, text, "\\\\\\1")
  end

  @spec markdown_alt(String.t()) :: String.t()
  defp markdown_alt(text) do
    text
    |> collapse_space()
    |> String.replace(~r/[\[\]\(\)]/, "")
    |> truncate(@headline_limit)
  end

  @spec image_alt(String.t() | nil) :: String.t()
  defp image_alt(nil), do: markdown_alt("preview image")
  defp image_alt(source), do: markdown_alt("#{source} preview image")

  @spec card_image_alt(Client.metadata(), String.t() | nil) :: String.t()
  defp card_image_alt(%{image_alt: alt}, _source) when is_binary(alt) and byte_size(alt) > 0 do
    markdown_alt(alt)
  end

  defp card_image_alt(_metadata, source), do: image_alt(source)

  @spec markdown_url(String.t()) :: String.t()
  defp markdown_url(url), do: String.replace(url, ">", "%3E")

  @spec fit_message(String.t()) :: String.t()
  defp fit_message(message) do
    if String.length(message) <= @message_limit do
      message
    else
      message
      |> String.graphemes()
      |> Enum.take(@message_limit - 3)
      |> Enum.join()
      |> Kernel.<>("...")
    end
  end

  # Titles arrive with newlines and runs of spaces from the source's own markup;
  # a headline that carries them breaks the line before it is truncated.
  @spec collapse_space(String.t()) :: String.t()
  defp collapse_space(text), do: text |> String.split() |> Enum.join(" ")

  @spec truncate(String.t(), pos_integer()) :: String.t()
  defp truncate(str, max) do
    if String.length(str) > max do
      String.slice(str, 0, max - 3) <> "..."
    else
      str
    end
  end
end
