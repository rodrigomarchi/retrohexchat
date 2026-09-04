defmodule RetroHexChat.Scraper.HTTP do
  @moduledoc """
  Fetches a page over HTTP and reads what its publisher says about it.

  The extractor is deliberately standards-led rather than scraper-led. It reads
  publisher-provided preview metadata from the document head:

    * Open Graph (`og:title`, `og:description`, `og:image`, `og:url`)
    * Twitter/X Cards (`twitter:title`, `twitter:description`, `twitter:image`)
    * Schema.org JSON-LD (`headline`, `name`, `description`, `image`)
    * HTML fallbacks (`<title>`, `meta[name=description]`, canonical link)
    * oEmbed JSON only when the page explicitly advertises a discovery link

  Every server-side URL fetch is checked by `RetroHexChat.Net.URLGuard`, including
  redirects and discovered oEmbed endpoints — at fetch time, not only when the URL
  was first accepted, because a name that resolved to a public address last month
  can be re-pointed at loopback today.

  Text is returned exactly as the publisher wrote it. Escaping belongs to whoever
  renders, and doing it here meant every consumer escaped a second time.
  """

  @behaviour RetroHexChat.Scraper.Client

  alias RetroHexChat.Net.URLGuard
  alias RetroHexChat.Scraper.Client

  require Logger

  @type metadata :: Client.metadata()
  @type fetch_error :: Client.error()
  @typep image_candidate :: %{
           optional(:alt) => String.t() | nil,
           optional(:base_score) => integer(),
           optional(:height) => pos_integer() | nil,
           optional(:marker_text) => String.t() | nil,
           optional(:raw_url) => String.t() | nil,
           optional(:rejected) => String.t() | nil,
           optional(:score) => integer(),
           optional(:selector) => String.t() | nil,
           optional(:source) => String.t(),
           optional(:source_kind) => :metadata | :document,
           optional(:url) => String.t() | nil,
           optional(:width) => pos_integer() | nil
         }
  @typep image_selection :: %{
           required(:candidates) => [image_candidate()],
           required(:selected) => image_candidate() | nil
         }
  @typep content_info :: %{
           text: String.t() | nil,
           truncated?: boolean(),
           strategy: String.t(),
           word_count: non_neg_integer() | nil,
           excerpt: String.t() | nil
         }

  # A ceiling, not a budget: high enough that no real page is cut short, low
  # enough that a hostile or runaway response cannot exhaust the node.
  @max_body_size 4_000_000
  @max_oembed_size 64_000
  @max_title_length 200
  @max_description_length 500
  @max_hint_description_audit_length 2_000
  @max_hint_content_text_length 50_000
  @max_excerpt_length 360
  @max_site_name_length 120
  @max_section_length 120
  @max_tag_length 48
  @max_tags 12
  @max_url_length 2_000
  @max_readability_candidates 80
  @max_redirects 3
  @image_min_score 70
  @image_audit_limit 12

  # The ceiling the transport allows, not the budget a caller gets. Reading a
  # whole document rather than stopping at `</head>` made 5s tight enough that
  # ordinary sites timed out and were recorded as unreachable. Callers that
  # cannot wait this long impose their own, shorter budget on top.
  @timeout_ms 15_000

  @html_accept "text/html, application/xhtml+xml;q=0.9, */*;q=0.1"
  @json_accept "application/json, application/*+json;q=0.9, */*;q=0.1"
  @user_agent "RetroHexChat-Scraper/1.0"
  @redirect_statuses [301, 302, 303, 307, 308]

  @impl true
  @spec scrape(String.t(), Client.opts()) ::
          {:ok, Client.scrape()} | {:not_modified} | {:error, fetch_error()}
  def scrape(url, opts \\ []) do
    with {:ok, html, final_url, headers, status} <- fetch_resource(url, :html, opts),
         true <- html_content?(first_header(headers, "content-type")),
         {:ok, document} <- parse_document(html),
         hints = metadata_hints(opts),
         {:ok, metadata, sources, oembed_url, image_selection} <-
           metadata_from_document(document, final_url, hints) do
      oembed_url = oembed_url || oembed_header_url(headers, final_url)
      content = extract_content_info(document)

      metadata = maybe_merge_oembed(metadata, oembed_url, final_url)

      if useful_scrape?(metadata, content.excerpt) do
        {:ok,
         build_scrape(
           metadata,
           sources,
           content,
           document,
           final_url,
           %{
             headers: headers,
             status: status,
             image_selection: image_selection,
             hints: hints
           }
         )}
      else
        {:error, empty_page_reason(html, headers)}
      end
    else
      false -> {:error, :not_html}
      {:not_modified} -> {:not_modified}
      {:error, reason} -> {:error, reason}
    end
  rescue
    exception ->
      # A page that breaks the extractor and a host that will not answer both
      # leave as `:fetch_failed`, so the log line is the only place the two stay
      # apart. Publishers nest objects where the schema says string, `to_string/1`
      # raises on them, and without this line that reads as an unreachable site.
      Logger.warning("scrape_raise url=#{url} error=#{Exception.message(exception)}")
      {:error, :fetch_failed}
  end

  # A bot wall answers every request, forever, with a page that has no metadata
  # in it. Left as `:no_metadata` that is a transient failure retried every
  # fifteen minutes for as long as the feed keeps carrying the link — Ars
  # Technica alone accounted for ten of one hundred and fifty-two links that way.
  #
  # Told apart, it becomes a verdict with a long expiry: still re-checked
  # eventually, because these walls do come down, but not hammered.
  #
  # Deliberately a *reclassification* of an already-empty result rather than a
  # gate before parsing. An article about Cloudflare that quotes `cf_chl_opt`
  # still extracts normally; only a page that yielded nothing at all is examined
  # for the markers.
  @challenge_scan_bytes 8_000
  @challenge_markers ~w(awswafcookie awswaf.js cf_chl_opt __cf_chl challenge-platform _incapsula_ distil_r_captcha)

  @spec empty_page_reason(String.t(), map()) :: :bot_challenge | :no_metadata
  defp empty_page_reason(html, headers) do
    if bot_challenge?(html, headers), do: :bot_challenge, else: :no_metadata
  end

  @spec bot_challenge?(String.t(), map()) :: boolean()
  defp bot_challenge?(html, headers) do
    # Cloudflare states it outright in a header; the rest are recognised by the
    # script their interstitial loads.
    first_header(headers, "cf-mitigated") != nil or
      html
      |> String.slice(0, @challenge_scan_bytes)
      |> String.downcase()
      |> then(fn head -> Enum.any?(@challenge_markers, &String.contains?(head, &1)) end)
  end

  @spec build_scrape(
          metadata(),
          map(),
          map(),
          Floki.html_tree(),
          String.t(),
          map()
        ) :: Client.scrape()
  defp build_scrape(
         metadata,
         sources,
         content,
         document,
         final_url,
         context
       ) do
    headers = Map.fetch!(context, :headers)
    status = Map.fetch!(context, :status)
    image_selection = Map.fetch!(context, :image_selection)
    hints = Map.fetch!(context, :hints)
    scope = head_scope(document)
    metas = meta_tags(scope)
    json_ld = json_ld_candidates(scope)
    content = enrich_content_info(content, hints)

    sources =
      if content.text, do: Map.put(sources, "content_text", content.strategy), else: sources

    author = author(metas, json_ld, document) || hint_author(hints)
    published_at = published_at(metas, json_ld, document) || hint_datetime(hints, :published_at)
    tags = merge_tags(tags(metas, json_ld, document), hint_tags(hints))

    quality =
      quality_audit(metadata, content, author, published_at, tags, image_selection, sources)

    %{
      metadata: metadata,
      final_url: final_url,
      http_status: status,
      content_type: first_header(headers, "content-type"),
      etag: first_header(headers, "etag"),
      last_modified: first_header(headers, "last-modified"),
      excerpt: content.excerpt,
      author: author,
      published_at: published_at,
      modified_at: modified_at(metas, json_ld, document),
      lang: lang(document, metas, json_ld),
      section: section(metas, json_ld, document),
      tags: tags,
      content_text: content.text,
      content_text_truncated: content.truncated?,
      content_word_count: content.word_count,
      raw_metadata: raw_metadata(metas, json_ld, sources, image_selection, hints, quality)
    }
  end

  # Generous, because the row is written once and read for four months. A page
  # long enough to hit this is a transcript or a book chapter, and the opening
  # 200k characters of one still answer far more than a truncation flag alone.
  @max_content_text_length 200_000

  @boilerplate ~w(script style noscript nav header footer aside form template iframe svg)

  @content_candidate_selectors ~w(
    [itemprop~=articleBody] [class*=ArticleBody] [class*=articleBody]
    [class*=article-body] [class*=story-body] [class*=StoryBody]
    [class*=content-body] [class*=post-body] [class*=entry-content]
    [data-component=ArticleBody] [data-testid*=article] [data-testid*=story]
    .entry-content .post-content .post__content .article-content .article-body
    .story-body .story-content .storyBody .articleBody .article__body
    .article-text .article-copy .article .post #content #main section div
  )

  # The page's own words, with the furniture removed.
  #
  # Prefers whatever the document itself calls its main content — `<article>`, then
  # `<main>` — and falls back to the body, because a page that names nothing still
  # has an article in it somewhere and a partly-noisy answer beats none. Which of
  # the three was used is recorded under `raw_metadata["sources"]["content_text"]`,
  # so a later reader can weigh it.
  @spec extract_content_info(Floki.html_tree()) :: content_info()
  defp extract_content_info(document) do
    document
    |> content_candidates()
    |> best_content_info()
  rescue
    _ -> %{text: nil, truncated?: false, strategy: "none", word_count: nil, excerpt: nil}
  end

  @spec enrich_content_info(
          content_info(),
          map()
        ) :: content_info()
  defp enrich_content_info(content, hints) do
    hint_text = hint_content_text(hints)
    hint_words = word_count(hint_text) || 0
    page_words = content.word_count || 0

    if present?(hint_text) and hint_words > page_words do
      %{
        text: hint_text,
        truncated?: false,
        strategy: "feed_item",
        word_count: hint_words,
        excerpt: excerpt(hint_text)
      }
    else
      content
    end
  end

  @spec content_candidates(Floki.html_tree()) :: [content_info()]
  defp content_candidates(document) do
    scope = head_scope(document)
    json_ld = json_ld_candidates(scope)

    [
      text_content_info(json_ld_article_body(json_ld), "json_ld_article_body"),
      text_content_info(microdata_article_body(document), "microdata_article_body")
      | html_content_candidates(document)
    ]
    |> Enum.reject(&is_nil/1)
  end

  @spec html_content_candidates(Floki.html_tree()) :: [content_info()]
  defp html_content_candidates(document) do
    explicit_content_candidates(document) ++
      readability_content_candidates(document) ++
      body_content_candidates(document)
  end

  @spec explicit_content_candidates(Floki.html_tree()) :: [content_info()]
  defp explicit_content_candidates(document) do
    [
      {"article", "article"},
      {"main", "main"},
      {"main", "[role=main]"},
      {"microdata_article_body", "[itemprop~=articleBody]"}
    ]
    |> Enum.flat_map(fn {strategy, selector} ->
      document
      |> Floki.find(selector)
      |> Enum.map(&scope_content_info([&1], strategy))
    end)
    |> Enum.reject(&is_nil/1)
  end

  @spec body_content_candidates(Floki.html_tree()) :: [content_info()]
  defp body_content_candidates(document) do
    case body_scope(document) do
      {scope, strategy} -> [scope_content_info(scope, strategy)]
      nil -> []
    end
  end

  @spec readability_content_candidates(Floki.html_tree()) :: [content_info()]
  defp readability_content_candidates(document) do
    @content_candidate_selectors
    |> Enum.flat_map(&Floki.find(document, &1))
    |> Enum.take(@max_readability_candidates)
    |> Enum.map(&{[&1], readability_score([&1])})
    |> Enum.reject(fn {_scope, score} -> score <= 0 end)
    |> Enum.map(fn {scope, _score} -> scope_content_info(scope, "readability") end)
    |> Enum.reject(&is_nil/1)
  end

  @spec scope_content_info(Floki.html_tree(), String.t()) :: content_info() | nil
  defp scope_content_info(scope, strategy) do
    scope
    |> readable_text()
    |> collapse_whitespace()
    |> text_content_info(strategy)
  end

  @spec text_content_info(String.t() | nil, String.t()) :: content_info() | nil
  defp text_content_info(text, strategy) when is_binary(text) do
    full_text = collapse_whitespace(text)

    case cap_content(full_text) do
      {nil, _truncated?} ->
        nil

      {text, truncated?} ->
        %{
          text: text,
          truncated?: truncated?,
          strategy: strategy,
          word_count: word_count(full_text),
          excerpt: excerpt(text)
        }
    end
  end

  defp text_content_info(_text, _strategy), do: nil

  @spec best_content_info([content_info()]) :: content_info()
  defp best_content_info(candidates) do
    Enum.max_by(
      candidates,
      &content_info_rank/1,
      fn -> %{text: nil, truncated?: false, strategy: "none", word_count: nil, excerpt: nil} end
    )
  end

  @content_strategy_weight %{
    "json_ld_article_body" => 1_200,
    "microdata_article_body" => 1_100,
    "article" => 900,
    "main" => 800,
    "readability" => 700,
    "body" => 100,
    "document" => 0
  }

  @spec content_info_rank(content_info()) :: integer()
  defp content_info_rank(%{strategy: strategy, word_count: word_count}) do
    Map.get(@content_strategy_weight, strategy, 0) + min(word_count || 0, 1_000)
  end

  @spec content_scope(Floki.html_tree()) :: {Floki.html_tree(), String.t()}
  defp content_scope(document) do
    Enum.find_value(
      [{"article", "article"}, {"main", "main"}, {"[role=main]", "main"}],
      readability_scope(document) || body_scope(document) || {document, "document"},
      fn {selector, strategy} ->
        case Floki.find(document, selector) do
          [] -> nil
          found -> {found, strategy}
        end
      end
    )
  end

  @min_candidate_text_length 180

  @spec readability_scope(Floki.html_tree()) :: {Floki.html_tree(), String.t()} | nil
  defp readability_scope(document) do
    @content_candidate_selectors
    |> Enum.flat_map(&Floki.find(document, &1))
    |> Enum.map(&{[&1], readability_score([&1])})
    |> Enum.reject(fn {_scope, score} -> score <= 0 end)
    |> Enum.max_by(&elem(&1, 1), fn -> nil end)
    |> case do
      nil -> nil
      {scope, _score} -> {scope, "readability"}
    end
  end

  @spec body_scope(Floki.html_tree()) :: {Floki.html_tree(), String.t()} | nil
  defp body_scope(document) do
    case Floki.find(document, "body") do
      [] -> nil
      found -> {found, "body"}
    end
  end

  @spec readability_score(Floki.html_tree()) :: integer()
  defp readability_score(scope) do
    text = readable_text(scope)
    length = String.length(text)

    if length < @min_candidate_text_length do
      0
    else
      paragraph_count = scope |> Floki.find("p") |> length()
      heading_count = ~w(h1 h2 h3) |> Enum.flat_map(&Floki.find(scope, &1)) |> length()
      link_length = scope |> Floki.find("a") |> Floki.text(sep: " ") |> String.length()
      list_item_count = scope |> Floki.find("li") |> length()
      form_control_count = scope |> Floki.find("input, button, select, textarea") |> length()
      comma_count = text |> String.graphemes() |> Enum.count(&(&1 == ","))
      link_density_penalty = div(link_length * 100, max(length, 1))

      length + paragraph_count * 120 + heading_count * 30 + comma_count * 8 -
        link_length * 2 - link_density_penalty * 25 - list_item_count * 25 -
        form_control_count * 100 - readability_marker_penalty(scope)
    end
  end

  @readability_noise_markers MapSet.new(~w(
    ad ads advertisement aside comment comments footer header menu nav newsletter
    promo recirculation recommend related share sidebar social sponsor sponsored
    subscribe trending widget
  ))

  @spec readability_marker_penalty(Floki.html_tree()) :: non_neg_integer()
  defp readability_marker_penalty(scope) do
    scope
    |> Enum.flat_map(&readability_marker_attrs/1)
    |> Enum.find_value(0, fn marker_text ->
      marker_text
      |> marker_tokens()
      |> Enum.find(&MapSet.member?(@readability_noise_markers, &1))
      |> case do
        nil -> nil
        _marker -> 500
      end
    end)
  end

  @spec readability_marker_attrs(Floki.html_node()) :: [String.t()]
  defp readability_marker_attrs({_tag, attrs, _children}) when is_list(attrs) do
    attrs
    |> Enum.filter(fn {key, _value} -> key in ["class", "id", "role", "aria-label"] end)
    |> Enum.map(fn {_key, value} -> to_string(value) end)
  end

  defp readability_marker_attrs(_node), do: []

  @spec readable_text(Floki.html_tree()) :: String.t()
  defp readable_text(scope) do
    @boilerplate
    |> Enum.reduce(scope, &Floki.filter_out(&2, &1))
    |> Floki.text(sep: " ")
  end

  @spec collapse_whitespace(String.t()) :: String.t()
  defp collapse_whitespace(text), do: text |> String.split() |> Enum.join(" ")

  @spec word_count(String.t() | nil) :: non_neg_integer() | nil
  defp word_count(text) when is_binary(text) and text != "" do
    text |> String.split() |> length()
  end

  defp word_count(_text), do: nil

  @spec cap_content(String.t()) :: {String.t() | nil, boolean()}
  defp cap_content(""), do: {nil, false}

  defp cap_content(text) do
    if String.length(text) > @max_content_text_length do
      {String.slice(text, 0, @max_content_text_length), true}
    else
      {text, false}
    end
  end

  @spec excerpt(String.t() | nil) :: String.t() | nil
  defp excerpt(nil), do: nil

  defp excerpt(text) do
    text
    |> truncate_text(@max_excerpt_length)
    |> blank_to_nil()
  end

  # `twitter:creator` is deliberately absent. It is as often the publication's own
  # handle as the writer's — Engadget puts `@engadget` there — so using it would
  # attribute an article to whoever runs the account. A missing byline is better
  # than a wrong one.
  @spec author([map()], [map()], Floki.html_tree()) :: String.t() | nil
  defp author(metas, json_ld, document) do
    [
      meta_content(metas, "property", "article:author"),
      meta_content(metas, "property", "og:article:author"),
      meta_content(metas, "name", "author"),
      meta_content(metas, "name", "byl"),
      meta_content(metas, "name", "parsely-author"),
      meta_content(metas, "name", "sailthru.author"),
      dc_meta_content(metas, "creator"),
      json_ld_value(json_ld, ["author.name", "creator.name", "author"]),
      microdata_author(document)
    ]
    |> first_present()
    |> then(&clean_text(&1, max: @max_site_name_length))
    |> Client.byline()
  end

  @spec published_at([map()], [map()], Floki.html_tree()) :: DateTime.t() | nil
  defp published_at(metas, json_ld, document) do
    [
      meta_content(metas, "property", "article:published_time"),
      meta_content(metas, "property", "og:article:published_time"),
      meta_content(metas, "name", "date"),
      meta_content(metas, "name", "pubdate"),
      meta_content(metas, "name", "parsely-pub-date"),
      meta_content(metas, "name", "sailthru.date"),
      dc_meta_content(metas, "date"),
      dc_meta_content(metas, "created"),
      json_ld_value(json_ld, ["datePublished", "dateCreated", "uploadDate"]),
      microdata_value(document, ~w(datePublished dateCreated uploadDate), :date),
      document |> Floki.find("time[datetime]") |> Floki.attribute("datetime") |> List.first()
    ]
    |> first_present()
    |> parse_datetime()
  end

  # Publishers write dates in whatever their CMS emits. ISO 8601 covers nearly
  # all of them; a bare date is the common remainder and is worth the extra
  # clause. Anything else is left `nil` rather than guessed at.
  @spec parse_datetime(String.t() | nil) :: DateTime.t() | nil
  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    value = String.trim(value)

    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, _reason} ->
        case Date.from_iso8601(value) do
          {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
          {:error, _reason} -> nil
        end
    end
  rescue
    _ -> nil
  end

  @spec modified_at([map()], [map()], Floki.html_tree()) :: DateTime.t() | nil
  defp modified_at(metas, json_ld, document) do
    [
      meta_content(metas, "property", "article:modified_time"),
      meta_content(metas, "property", "og:updated_time"),
      meta_content(metas, "name", "lastmod"),
      meta_content(metas, "name", "datemodified"),
      dc_meta_content(metas, "modified"),
      json_ld_value(json_ld, ["dateModified", "dateUpdated"]),
      microdata_value(document, ~w(dateModified dateUpdated), :date),
      document
      |> Floki.find(~s(time[itemprop="dateModified"][datetime]))
      |> Floki.attribute("datetime")
      |> List.first()
    ]
    |> first_present()
    |> parse_datetime()
  end

  @spec lang(Floki.html_tree(), [map()], [map()]) :: String.t() | nil
  defp lang(document, metas, json_ld) do
    [
      document |> Floki.attribute("html", "lang") |> List.first(),
      meta_content(metas, "property", "og:locale"),
      meta_content(metas, "http-equiv", "content-language"),
      json_ld_value(json_ld, ["inLanguage"])
    ]
    |> first_present()
    |> then(&clean_text(&1, max: 32))
  end

  @spec section([map()], [map()], Floki.html_tree()) :: String.t() | nil
  defp section(metas, json_ld, document) do
    [
      meta_content(metas, "property", "article:section"),
      meta_content(metas, "name", "section"),
      meta_content(metas, "name", "parsely-section"),
      meta_content(metas, "name", "sailthru.vertical"),
      json_ld_value(json_ld, ["articleSection", "section.name", "about.name"]),
      microdata_value(document, ~w(articleSection genre), :text)
    ]
    |> first_present()
    |> then(&clean_text(&1, max: @max_section_length))
  end

  @spec tags([map()], [map()], Floki.html_tree()) :: [String.t()]
  defp tags(metas, json_ld, document) do
    [
      meta_values(metas, "property", "article:tag"),
      meta_values(metas, "name", "keywords"),
      meta_values(metas, "name", "news_keywords"),
      meta_values(metas, "name", "parsely-tags"),
      meta_values(metas, "name", "sailthru.tags"),
      dc_meta_values(metas, "subject"),
      json_ld_values(json_ld, ["keywords", "about.name"]),
      microdata_values(document, ~w(keywords about), :text)
    ]
    |> List.flatten()
    |> Enum.flat_map(&split_tag_value/1)
    |> Enum.map(&clean_text(&1, max: @max_tag_length))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.take(@max_tags)
  end

  # Everything the page said that did not earn a column of its own, plus which
  # standard each column came from. One place to look when a stored title is
  # wrong, and no need to re-fetch the page to find out why.
  @spec raw_metadata([map()], [map()], map(), image_selection(), map(), map()) :: map()
  defp raw_metadata(metas, json_ld, sources, image_selection, hints, quality) do
    %{}
    |> put_unless_empty("sources", sources)
    |> put_unless_empty("quality", quality)
    |> put_unless_empty("feed_item", feed_item_hints_audit(hints))
    |> put_unless_empty("og", namespaced_metas(metas, "property", "og:"))
    |> put_unless_empty("article", namespaced_metas(metas, "property", "article:"))
    |> put_unless_empty("twitter", namespaced_metas(metas, "name", "twitter:"))
    |> put_unless_empty("json_ld", json_ld)
    |> put_unless_empty("image_selection", image_selection_audit(image_selection))
  end

  @spec quality_audit(
          metadata(),
          content_info(),
          String.t() | nil,
          DateTime.t() | nil,
          [String.t()],
          image_selection(),
          map()
        ) :: map()
  defp quality_audit(metadata, content, author, published_at, tags, image_selection, sources) do
    missing = missing_quality_fields(metadata, content, author, published_at, tags)

    %{}
    |> put_unless_empty("score", quality_score(metadata, content, author, published_at, tags))
    |> put_unless_empty("missing", missing)
    |> put_unless_empty("title_source", Map.get(sources, "title"))
    |> put_unless_empty("description_source", Map.get(sources, "description"))
    |> put_unless_empty("image_source", Map.get(sources, "image"))
    |> put_unless_empty("content_strategy", content.strategy)
    |> put_unless_empty("content_word_count", content.word_count)
    |> put_unless_empty("image_selected_source", selected_image_source(image_selection))
  end

  @spec missing_quality_fields(
          metadata(),
          content_info(),
          String.t() | nil,
          DateTime.t() | nil,
          [String.t()]
        ) :: [String.t()]
  defp missing_quality_fields(metadata, content, author, published_at, tags) do
    [
      {"title", metadata[:title]},
      {"description", metadata[:description]},
      {"image", metadata[:image]},
      {"author", author},
      {"published_at", published_at},
      {"tags", tags},
      {"content_text", content.text}
    ]
    |> Enum.flat_map(fn {field, value} -> if quality_present?(value), do: [], else: [field] end)
  end

  @spec quality_score(metadata(), content_info(), String.t() | nil, DateTime.t() | nil, [
          String.t()
        ]) ::
          non_neg_integer()
  defp quality_score(metadata, content, author, published_at, tags) do
    [
      {metadata[:title], 20},
      {metadata[:description], 20},
      {metadata[:image], 15},
      {author, 10},
      {published_at, 10},
      {tags, 5},
      {content.text, content_score(content)}
    ]
    |> Enum.reduce(0, fn {value, points}, score ->
      if quality_present?(value), do: score + points, else: score
    end)
    |> min(100)
  end

  @spec content_score(content_info()) :: non_neg_integer()
  defp content_score(%{word_count: words}) when is_integer(words) and words >= 300, do: 20
  defp content_score(%{word_count: words}) when is_integer(words) and words >= 100, do: 14
  defp content_score(%{word_count: words}) when is_integer(words) and words >= 30, do: 8
  defp content_score(_content), do: 0

  @spec quality_present?(term()) :: boolean()
  defp quality_present?(value) when is_binary(value), do: String.trim(value) != ""
  defp quality_present?(value) when is_list(value), do: Enum.any?(value, &quality_present?/1)
  defp quality_present?(nil), do: false
  defp quality_present?(_value), do: true

  @spec selected_image_source(image_selection()) :: String.t() | nil
  defp selected_image_source(%{selected: %{source: source}}) when is_binary(source), do: source
  defp selected_image_source(_selection), do: nil

  @spec feed_item_hints_audit(map()) :: map()
  defp feed_item_hints_audit(hints) do
    source =
      case hint_value(hints, :feed_item) do
        value when is_map(value) -> value
        _other -> %{}
      end

    [
      {"title", [:title], @max_title_length},
      {"link", [:link], @max_url_length},
      {"guid", [:guid], @max_url_length},
      {"published", [:published], @max_title_length},
      {"published_at", [:published_at], @max_title_length},
      {"description", [:description], @max_hint_description_audit_length},
      {"content_text", [:content_text], @max_hint_content_text_length},
      {"author", [:author], @max_site_name_length},
      {"categories", [:categories, :tags], @max_tag_length},
      {"image_url", [:image_url, :image], @max_url_length},
      {"image_alt", [:image_alt], @max_title_length},
      {"image_source", [:image_source], @max_site_name_length}
    ]
    |> Enum.reduce(%{}, fn {field, keys, max}, audit ->
      value = hint_value_any(source, keys) || hint_value_any(hints, keys)
      put_unless_empty(audit, field, audit_hint_value(field, value, max))
    end)
  end

  @spec audit_hint_value(String.t(), term(), pos_integer()) :: term()
  defp audit_hint_value("published_at", %DateTime{} = datetime, _max),
    do: DateTime.to_iso8601(datetime)

  defp audit_hint_value("categories", value, _max), do: normalize_hint_tags(value)

  defp audit_hint_value(_field, value, max) when is_binary(value) or is_number(value),
    do: clean_text(value, max: max)

  defp audit_hint_value(_field, _value, _max), do: nil

  @spec namespaced_metas([map()], String.t(), String.t()) :: map()
  defp namespaced_metas(metas, key, prefix) do
    metas
    |> Enum.filter(fn attrs ->
      attrs |> Map.get(key) |> normalize_key() |> to_string() |> String.starts_with?(prefix)
    end)
    |> Map.new(fn attrs ->
      {attrs |> Map.get(key) |> normalize_key(), Map.get(attrs, "content")}
    end)
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  @spec put_unless_empty(map(), String.t(), term()) :: map()
  defp put_unless_empty(map, _key, nil), do: map
  defp put_unless_empty(map, _key, value) when value == %{} or value == [], do: map
  defp put_unless_empty(map, key, value), do: Map.put(map, key, value)

  @json_ld_preferred_types MapSet.new(~w(
    AnalysisNewsArticle
    Article
    BlogPosting
    LiveBlogPosting
    NewsArticle
    OpinionNewsArticle
    Product
    Recipe
    ReportageNewsArticle
    ReviewNewsArticle
    ScholarlyArticle
    SocialMediaPosting
    TechArticle
    VideoObject
    WebPage
    WebSite
  ))

  # Fetches rich preview metadata while preserving retry-relevant error detail.
  @spec fetch_metadata_result(String.t()) :: {:ok, metadata()} | {:error, fetch_error()}
  def fetch_metadata_result(url) do
    case scrape(url, []) do
      {:ok, %{metadata: metadata}} -> ensure_useful_metadata(metadata)
      {:not_modified} -> {:error, :not_modified}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extracts standards-based preview metadata from already-fetched HTML.
  """
  @spec parse_metadata(String.t(), String.t() | nil) :: {:ok, metadata()} | {:error, atom()}
  def parse_metadata(html, page_url \\ nil) when is_binary(html) do
    with {:ok, document} <- parse_document(html),
         {:ok, metadata, _sources, _oembed_url, _image_selection} <-
           metadata_from_document(document, page_url, %{}) do
      ensure_useful_metadata(metadata)
    end
  end

  @typep resource ::
           {:ok, String.t(), String.t(), map(), pos_integer()}
           | {:not_modified}
           | {:error, fetch_error()}

  @spec fetch_resource(String.t(), :html | :json, Client.opts()) :: resource()
  defp fetch_resource(url, kind, opts),
    do: fetch_resource(url, kind, opts, @max_redirects)

  @spec fetch_resource(String.t(), :html | :json, Client.opts(), non_neg_integer()) :: resource()
  defp fetch_resource(url, kind, opts, redirects_left) do
    case URLGuard.fetch_target(url) do
      {:ok, target} -> fetch_resource_target(target, url, kind, opts, redirects_left)
      {:error, _reason} -> {:error, :blocked}
    end
  end

  @spec fetch_resource_target(
          URLGuard.fetch_target(),
          String.t(),
          :html | :json,
          Client.opts(),
          non_neg_integer()
        ) :: resource()
  defp fetch_resource_target(target, url, kind, opts, redirects_left) do
    case request_once(target, kind, opts) do
      {:ok, response} ->
        handle_resource_response(response, url, kind, opts, redirects_left)

      {:error, reason} ->
        Logger.warning("scrape_transport_error url=#{url} reason=#{inspect(reason)}")
        {:error, :fetch_failed}
    end
  end

  @spec handle_resource_response(
          Req.Response.t(),
          String.t(),
          :html | :json,
          Client.opts(),
          non_neg_integer()
        ) :: resource()
  defp handle_resource_response(
         %{status: status, body: body, headers: headers},
         url,
         _kind,
         _opts,
         _redirects_left
       )
       when status in 200..299 do
    {:ok, decode_body(body, first_header(headers, "content-type")), url, headers, status}
  end

  # The publisher says the page is exactly what we already stored. Nothing was
  # transferred, so there is nothing to parse — only a row to renew.
  defp handle_resource_response(%{status: 304}, _url, _kind, _opts, _redirects_left),
    do: {:not_modified}

  defp handle_resource_response(
         %{status: status, headers: headers},
         url,
         kind,
         opts,
         redirects_left
       )
       when status in @redirect_statuses do
    follow_redirect(url, headers, kind, opts, redirects_left)
  end

  defp handle_resource_response(%{status: status}, _url, _kind, _opts, _redirects_left)
       when is_integer(status),
       do: {:error, {:http_status, status}}

  @spec request_once(URLGuard.fetch_target(), :html | :json, Client.opts()) ::
          {:ok, Req.Response.t()} | {:error, term()}
  defp request_once(target, kind, opts) do
    Req.get(request_options(target, kind, opts))
  end

  @spec request_options(URLGuard.fetch_target(), :html | :json, Client.opts()) :: keyword()
  defp request_options(target, kind, opts) do
    target
    |> base_request_options(kind, opts)
    |> merge_request_overrides()
  end

  @spec base_request_options(URLGuard.fetch_target(), :html | :json, Client.opts()) :: keyword()
  defp base_request_options(target, kind, opts) do
    options = [
      url: target.url,
      headers: request_headers(kind) ++ conditional_headers(opts),
      redirect: false,
      compressed: false,
      decode_body: false,
      max_retries: 0,
      connect_options: Keyword.put(target.connect_options, :timeout, @timeout_ms),
      receive_timeout: @timeout_ms,
      into: collector(kind, opts)
    ]

    if Map.get(target, :inet6?) do
      Keyword.put(options, :inet6, true)
    else
      options
    end
  end

  @spec merge_request_overrides(keyword()) :: keyword()
  defp merge_request_overrides(options) do
    Keyword.merge(options, request_overrides(), fn
      :connect_options, left, right -> Keyword.merge(left, right)
      _key, _left, right -> right
    end)
  end

  @spec request_headers(:html | :json) :: [{String.t(), String.t()}]
  defp request_headers(:html), do: [{"user-agent", @user_agent}, {"accept", @html_accept}]
  defp request_headers(:json), do: [{"user-agent", @user_agent}, {"accept", @json_accept}]

  # Offers the publisher the chance to answer "unchanged" instead of resending a
  # page we already hold. With a 60-day archive this is the difference between
  # refreshing a row and re-downloading the internet.
  @spec conditional_headers(Client.opts()) :: [{String.t(), String.t()}]
  defp conditional_headers(opts) do
    [{"if-none-match", opts[:if_none_match]}, {"if-modified-since", opts[:if_modified_since]}]
    |> Enum.filter(fn {_name, value} -> is_binary(value) and value != "" end)
  end

  @spec request_overrides() :: keyword()
  defp request_overrides do
    Application.get_env(:retro_hex_chat, :scraper_req_options, [])
  end

  # Read the whole document, not just its head. The head carries the preview
  # fields, but the body carries the article — and having paid for the connection,
  # the round trip and the transfer, stopping early only guarantees a second visit
  # the day anything wants to read what the page actually said.
  @spec collector(:html | :json, Client.opts()) :: function()
  defp collector(:json, _opts), do: &collect_limited_body(&1, &2, @max_oembed_size)
  defp collector(:html, _opts), do: &collect_limited_body(&1, &2, @max_body_size)

  @spec collect_limited_body(
          {:data, binary()},
          {Req.Request.t(), Req.Response.t()},
          pos_integer()
        ) ::
          {:cont | :halt, {Req.Request.t(), Req.Response.t()}}
  defp collect_limited_body({:data, data}, {request, response}, max_size) do
    current = if is_binary(response.body), do: response.body, else: ""
    remaining = max(max_size - byte_size(current), 0)
    data = binary_part(data, 0, min(byte_size(data), remaining))
    body = current <> data
    response = %{response | body: body}

    if byte_size(body) >= max_size do
      {:halt, {request, response}}
    else
      {:cont, {request, response}}
    end
  end

  @spec follow_redirect(String.t(), map(), :html | :json, Client.opts(), non_neg_integer()) ::
          resource()
  defp follow_redirect(_url, _headers, _kind, _opts, 0), do: {:error, :too_many_redirects}

  defp follow_redirect(url, headers, kind, opts, redirects_left) do
    case redirect_url(url, first_header(headers, "location")) do
      nil -> {:error, :server_error}
      next_url -> fetch_resource(next_url, kind, opts, redirects_left - 1)
    end
  end

  @spec redirect_url(String.t(), String.t() | nil) :: String.t() | nil
  defp redirect_url(_url, nil), do: nil

  defp redirect_url(url, location) do
    url
    |> URI.merge(String.trim(location))
    |> URI.to_string()
  rescue
    _ -> nil
  end

  @spec parse_document(String.t()) :: {:ok, Floki.html_tree()} | {:error, :parse_failed}
  defp parse_document(html) do
    case Floki.parse_document(html) do
      {:ok, document} -> {:ok, document}
      {:error, _reason} -> {:error, :parse_failed}
    end
  end

  @spec metadata_from_document(Floki.html_tree(), String.t() | nil, map()) ::
          {:ok, metadata(), map(), String.t() | nil, image_selection()}
  defp metadata_from_document(document, page_url, hints) do
    scope = head_scope(document)
    metas = meta_tags(scope)
    links = link_tags(scope)
    json_ld = json_ld_candidates(scope)

    {title, title_source} = title(metas, json_ld, scope, document)
    {description, description_source} = description(metas, json_ld, document)
    {site_name, site_name_source} = site_name(metas, json_ld)
    {url_value, url_source} = page_url(metas, links, page_url, document)
    {image_alt, image_alt_source} = image_alt(metas, json_ld)
    image_selection = image_selection(document, metas, json_ld, hints, page_url)
    selected_image = image_selection.selected
    {image, image_source} = selected_image_value(selected_image)

    {title, title_source} =
      labelled_fallback({title, title_source}, hint_value(hints, :title), "feed_item",
        max: @max_title_length
      )

    {description, description_source} =
      labelled_fallback({description, description_source}, hint_description(hints), "feed_item",
        max: @max_description_length
      )

    {image_alt, image_alt_source} =
      selected_image_alt(selected_image, image_alt, image_alt_source)

    metadata =
      %{}
      |> put_clean(:title, title)
      |> put_clean(:description, description)
      |> put_clean(:site_name, site_name)
      |> put_clean(:image_alt, image_alt)
      |> put_url(:url, url_value, page_url, :page)
      |> put_url(:image, image, page_url, :image)

    sources =
      %{
        "title" => title_source,
        "description" => description_source,
        "site_name" => site_name_source,
        "url" => url_source,
        "image" => image_source,
        "image_alt" => image_alt_source
      }
      |> Map.take(metadata |> Map.keys() |> Enum.map(&Atom.to_string/1))
      |> Map.reject(fn {_key, source} -> is_nil(source) end)

    {:ok, metadata, sources, oembed_url(links, page_url), image_selection}
  end

  @spec head_scope(Floki.html_tree()) :: Floki.html_tree()
  defp head_scope(document) do
    case Floki.find(document, "head") do
      [] -> document
      heads -> heads
    end
  end

  @spec title([map()], [map()], Floki.html_tree(), Floki.html_tree()) ::
          {String.t() | nil, String.t() | nil}
  defp title(metas, json_ld, scope, document) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:title")},
      {"twitter", meta_content(metas, "name", "twitter:title")},
      {"json_ld", json_ld_value(json_ld, ["headline", "name"])},
      {"parsely", meta_content(metas, "name", "parsely-title")},
      {"sailthru", meta_content(metas, "name", "sailthru.title")},
      {"dc", dc_meta_content(metas, "title")},
      {"microdata", microdata_value(document, ~w(headline), :text)},
      {"html", scope |> Floki.find("title") |> Floki.text()},
      {"heading", heading_title(document)},
      {"microdata", microdata_value(document, ~w(name), :text)}
    ])
  end

  @spec description([map()], [map()], Floki.html_tree()) ::
          {String.t() | nil, String.t() | nil}
  defp description(metas, json_ld, document) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:description")},
      {"twitter", meta_content(metas, "name", "twitter:description")},
      {"json_ld", json_ld_value(json_ld, ["description"])},
      {"parsely", meta_content(metas, "name", "parsely-summary")},
      {"sailthru", meta_content(metas, "name", "sailthru.description")},
      {"dc", dc_meta_content(metas, "description")},
      {"microdata", microdata_value(document, ~w(description), :text)},
      {"html", meta_content(metas, "name", "description")}
    ])
  end

  @spec site_name([map()], [map()]) :: {String.t() | nil, String.t() | nil}
  defp site_name(metas, json_ld) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:site_name")},
      {"html", meta_content(metas, "name", "application-name")},
      {"dc", dc_meta_content(metas, "publisher")},
      {"json_ld", json_ld_value(json_ld, ["publisher.name", "provider.name"])}
    ])
  end

  @spec page_url([map()], [map()], String.t() | nil, Floki.html_tree()) ::
          {String.t() | nil, String.t() | nil}
  defp page_url(metas, links, fallback, document) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:url")},
      {"twitter", meta_content(metas, "name", "twitter:url")},
      {"canonical", canonical_url(links)},
      {"microdata", microdata_value(document, ~w(url mainEntityOfPage), :url)},
      {"request", fallback}
    ])
  end

  @spec image_alt([map()], [map()]) :: {String.t() | nil, String.t() | nil}
  defp image_alt(metas, json_ld) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:image:alt")},
      {"twitter", meta_content(metas, "name", "twitter:image:alt")},
      {"json_ld", json_ld_image_alt(json_ld)}
    ])
  end

  @spec heading_title(Floki.html_tree()) :: String.t() | nil
  defp heading_title(document) do
    document
    |> content_scope()
    |> elem(0)
    |> Floki.find("h1")
    |> Floki.text(sep: " ")
    |> clean_text(max: @max_title_length)
  rescue
    _ -> nil
  end

  @metadata_image_candidates [
    {"og", "property", "og:image:secure_url", 104},
    {"og", "property", "og:image:url", 104},
    {"og", "property", "og:image", 102},
    {"twitter", "name", "twitter:image", 96},
    {"twitter", "name", "twitter:image:src", 96},
    {"parsely", "name", "parsely-image-url", 94},
    {"sailthru", "name", "sailthru.image.full", 92},
    {"sailthru", "name", "sailthru.image.thumb", 88}
  ]

  @document_image_scopes [
    {"article", "article img", 78},
    {"main", "main img", 74},
    {"main", "[role=main] img", 74},
    {"readability", ".entry-content img", 72},
    {"readability", ".post-content img", 72},
    {"readability", ".article-content img", 72},
    {"readability", ".article-body img", 72},
    {"readability", ".story-body img", 72},
    {"readability", "#content img", 68},
    {"readability", "#main img", 68},
    {"readability", ".article img", 68},
    {"readability", ".post img", 68},
    {"figure", "figure img", 68},
    {"body", "body img", 15}
  ]

  @decorative_container_selectors [
    {"header img", "decorative_container:header"},
    {"nav img", "decorative_container:nav"},
    {"footer img", "decorative_container:footer"},
    {"aside img", "decorative_container:aside"},
    {".related img", "decorative_container:related"},
    {".recommend img", "decorative_container:recommend"},
    {".recommendation img", "decorative_container:recommend"},
    {".popular img", "decorative_container:popular"},
    {".share img", "decorative_container:share"},
    {".social img", "decorative_container:social"},
    {".download img", "decorative_container:download"},
    {".appDownload img", "decorative_container:download"},
    {".app-download img", "decorative_container:download"},
    {".qrcode img", "decorative_container:qrcode"},
    {".qr-code img", "decorative_container:qrcode"},
    {"[class*=Related] img", "decorative_container:related"},
    {"[class*=related] img", "decorative_container:related"},
    {"[class*=Recommend] img", "decorative_container:recommend"},
    {"[class*=recommend] img", "decorative_container:recommend"},
    {"[class*=Share] img", "decorative_container:share"},
    {"[class*=share] img", "decorative_container:share"},
    {"[class*=Social] img", "decorative_container:social"},
    {"[class*=social] img", "decorative_container:social"},
    {"[class*=Download] img", "decorative_container:download"},
    {"[class*=download] img", "decorative_container:download"},
    {"[class*=QRCode] img", "decorative_container:qrcode"},
    {"[class*=qrcode] img", "decorative_container:qrcode"},
    {"[class*=qr-code] img", "decorative_container:qrcode"},
    {"[id*=Related] img", "decorative_container:related"},
    {"[id*=related] img", "decorative_container:related"},
    {"[id*=Recommend] img", "decorative_container:recommend"},
    {"[id*=recommend] img", "decorative_container:recommend"},
    {"[id*=Share] img", "decorative_container:share"},
    {"[id*=share] img", "decorative_container:share"},
    {"[id*=Download] img", "decorative_container:download"},
    {"[id*=download] img", "decorative_container:download"},
    {"[id*=QRCode] img", "decorative_container:qrcode"},
    {"[id*=qrcode] img", "decorative_container:qrcode"},
    {"[id*=qr-code] img", "decorative_container:qrcode"}
  ]

  @decorative_image_markers MapSet.new(~w(
    adserver
    appdownload
    avatar
    badge
    banner
    barcode
    button
    captcha
    close
    download
    footer
    header
    icon
    loading
    logo
    menu
    nav
    pixel
    placeholder
    promo
    qrcode
    recommend
    related
    search
    share
    social
    spinner
    sprite
    subscribe
    tracking
    wechat
    weibo
    weixin
  ))

  @metadata_image_sources ~w(feed_media og twitter json_ld parsely sailthru microdata)

  @spec metadata_hints(Client.opts()) :: map()
  defp metadata_hints(opts) do
    case Keyword.get(opts, :metadata_hints, %{}) do
      hints when is_map(hints) -> hints
      _other -> %{}
    end
  end

  @spec hint_description(map()) :: String.t() | nil
  defp hint_description(hints) do
    first_present([hint_value(hints, :description), hint_value(hints, :content_text)])
  end

  @spec hint_content_text(map()) :: String.t() | nil
  defp hint_content_text(hints) do
    hints
    |> hint_value(:content_text)
    |> clean_text(max: @max_hint_content_text_length)
  end

  @spec hint_author(map()) :: String.t() | nil
  defp hint_author(hints) do
    hints
    |> hint_value(:author)
    |> clean_text(max: @max_site_name_length)
    |> Client.byline()
  end

  @spec hint_datetime(map(), atom()) :: DateTime.t() | nil
  defp hint_datetime(hints, key) do
    case hint_value(hints, key) do
      %DateTime{} = datetime -> datetime
      value when is_binary(value) -> parse_datetime(value)
      _other -> nil
    end
  end

  @spec hint_tags(map()) :: [String.t()]
  defp hint_tags(hints) do
    hints
    |> hint_value(:tags)
    |> normalize_hint_tags()
  end

  @spec normalize_hint_tags(term()) :: [String.t()]
  defp normalize_hint_tags(values) do
    values
    |> List.wrap()
    |> Enum.flat_map(&split_tag_value/1)
    |> Enum.map(&clean_text(&1, max: @max_tag_length))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.take(@max_tags)
  end

  @spec merge_tags([String.t()], [String.t()]) :: [String.t()]
  defp merge_tags(page_tags, hint_tags) do
    (page_tags ++ hint_tags)
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.take(@max_tags)
  end

  @spec image_selection(Floki.html_tree(), [map()], [map()], map(), String.t() | nil) ::
          image_selection()
  defp image_selection(document, metas, json_ld, hints, page_url) do
    candidates =
      metadata_image_candidates(document, metas, json_ld, hints, page_url) ++
        document_image_candidates(document, page_url)

    candidates
    |> Enum.map(&score_image_candidate/1)
    |> dedupe_image_candidates()
    |> select_ranked_image()
  end

  @spec selected_image_value(image_candidate() | nil) :: {String.t() | nil, String.t() | nil}
  defp selected_image_value(%{url: url, source: source}) when is_binary(url), do: {url, source}
  defp selected_image_value(_candidate), do: {nil, nil}

  @spec selected_image_alt(image_candidate() | nil, String.t() | nil, String.t() | nil) ::
          {String.t() | nil, String.t() | nil}
  defp selected_image_alt(%{alt: alt, source: source}, _fallback_alt, _fallback_source)
       when is_binary(alt) do
    {alt, source}
  end

  defp selected_image_alt(%{source: source}, fallback_alt, fallback_source)
       when source in @metadata_image_sources do
    {fallback_alt, fallback_source}
  end

  defp selected_image_alt(_selected, _fallback_alt, _fallback_source), do: {nil, nil}

  @spec metadata_image_candidates(Floki.html_tree(), [map()], [map()], map(), String.t() | nil) ::
          [
            image_candidate()
          ]
  defp metadata_image_candidates(document, metas, json_ld, hints, page_url) do
    feed_image_candidates(hints, page_url) ++
      Enum.flat_map(@metadata_image_candidates, fn {source, key, wanted, score} ->
        metas
        |> meta_values(key, wanted)
        |> Enum.map(fn value ->
          image_candidate(value, page_url,
            source: source,
            source_kind: :metadata,
            base_score: score
          )
        end)
      end) ++
      json_ld_image_candidates(json_ld, page_url) ++
      microdata_image_candidates(document, page_url)
  end

  @spec microdata_image_candidates(Floki.html_tree(), String.t() | nil) :: [image_candidate()]
  defp microdata_image_candidates(document, page_url) do
    document
    |> microdata_values(~w(image thumbnailUrl primaryImageOfPage), :image)
    |> Enum.map(fn value ->
      image_candidate(value, page_url,
        source: "microdata",
        source_kind: :metadata,
        base_score: 88
      )
    end)
  end

  @spec feed_image_candidates(map(), String.t() | nil) :: [image_candidate()]
  defp feed_image_candidates(hints, page_url) do
    case hint_value(hints, :image) do
      image when is_binary(image) ->
        [
          image_candidate(image, page_url,
            source: "feed_media",
            source_kind: :metadata,
            selector: clean_text(hint_value(hints, :image_source), max: @max_site_name_length),
            alt: clean_text(hint_value(hints, :image_alt), max: @max_title_length),
            base_score: 112
          )
        ]

      _other ->
        []
    end
  end

  @spec hint_value(map(), atom()) :: term()
  defp hint_value(hints, key) do
    [Map.get(hints, key), Map.get(hints, Atom.to_string(key))]
    |> Enum.find_value(fn
      nil -> nil
      "" -> nil
      [] -> nil
      value -> value
    end)
  end

  @spec hint_value_any(map(), [atom()]) :: term()
  defp hint_value_any(hints, keys) do
    Enum.find_value(keys, fn key ->
      case hint_value(hints, key) do
        nil -> nil
        "" -> nil
        [] -> nil
        value -> value
      end
    end)
  end

  @spec json_ld_image_candidates([map()], String.t() | nil) :: [image_candidate()]
  defp json_ld_image_candidates(json_ld, page_url) do
    json_ld
    |> Enum.flat_map(&json_ld_image_values/1)
    |> Enum.map(fn {value, alt, width, height} ->
      image_candidate(value, page_url,
        source: "json_ld",
        source_kind: :metadata,
        alt: clean_text(alt, max: @max_title_length),
        width: width,
        height: height,
        base_score: 92
      )
    end)
  end

  @spec json_ld_image_values(map()) :: [
          {term(), term(), pos_integer() | nil, pos_integer() | nil}
        ]
  defp json_ld_image_values(candidate) do
    candidate
    |> Map.get("image")
    |> do_json_ld_image_values()
    |> then(fn images ->
      case candidate |> get_raw_path("thumbnailUrl") |> json_ld_scalar() do
        nil -> images
        thumbnail -> images ++ [{thumbnail, nil, nil, nil}]
      end
    end)
  end

  @spec do_json_ld_image_values(term()) :: [
          {term(), term(), pos_integer() | nil, pos_integer() | nil}
        ]
  defp do_json_ld_image_values(values) when is_list(values),
    do: Enum.flat_map(values, &do_json_ld_image_values/1)

  defp do_json_ld_image_values(value) when is_binary(value), do: [{value, nil, nil, nil}]

  defp do_json_ld_image_values(%{} = value) do
    case first_url_value([Map.get(value, "url"), Map.get(value, "contentUrl")]) do
      nil ->
        []

      url ->
        [
          {url, image_alt_value(value), dimension(Map.get(value, "width")),
           dimension(Map.get(value, "height"))}
        ]
    end
  end

  defp do_json_ld_image_values(_value), do: []

  @spec first_url_value([term()]) :: String.t() | nil
  defp first_url_value(values) do
    Enum.find_value(values, &clean_url/1)
  end

  @spec document_image_candidates(Floki.html_tree(), String.t() | nil) :: [image_candidate()]
  defp document_image_candidates(document, page_url) do
    decorative_urls = decorative_container_image_urls(document, page_url)

    @document_image_scopes
    |> Enum.flat_map(fn {scope, selector, base_score} ->
      document
      |> Floki.find(selector)
      |> Enum.map(fn node ->
        node
        |> document_image_candidate(page_url, selector, base_score)
        |> reject_decorative_container(decorative_urls)
        |> Map.put(:selector, scope)
      end)
    end)
  end

  @spec document_image_candidate(Floki.html_node(), String.t() | nil, String.t(), integer()) ::
          image_candidate()
  defp document_image_candidate(node, page_url, selector, base_score) do
    attrs = attrs_map(node)

    image_candidate(image_src(attrs), page_url,
      source: "article_image",
      source_kind: :document,
      selector: selector,
      alt: clean_text(Map.get(attrs, "alt"), max: @max_title_length),
      width: dimension(Map.get(attrs, "width")),
      height: dimension(Map.get(attrs, "height")),
      marker_text: image_marker_text(attrs, selector),
      base_score: base_score
    )
  end

  @spec image_candidate(term(), String.t() | nil, keyword()) :: image_candidate()
  defp image_candidate(raw_value, page_url, opts) do
    raw_url = clean_url(raw_value)
    url = normalize_url(raw_url, page_url, :image)

    %{
      url: url,
      raw_url: raw_url,
      source: Keyword.fetch!(opts, :source),
      source_kind: Keyword.get(opts, :source_kind, :metadata),
      selector: Keyword.get(opts, :selector),
      alt: Keyword.get(opts, :alt),
      width: Keyword.get(opts, :width),
      height: Keyword.get(opts, :height),
      marker_text: Keyword.get(opts, :marker_text),
      base_score: Keyword.fetch!(opts, :base_score)
    }
  end

  @spec score_image_candidate(image_candidate()) :: image_candidate()
  defp score_image_candidate(%{url: nil} = candidate),
    do: Map.put(candidate, :rejected, "invalid_or_blocked_url")

  defp score_image_candidate(candidate) do
    case image_rejection_reason(candidate) do
      nil ->
        Map.put(candidate, :score, image_candidate_score(candidate))

      reason ->
        Map.put(candidate, :rejected, reason)
    end
  end

  @spec image_rejection_reason(image_candidate()) :: String.t() | nil
  defp image_rejection_reason(candidate) do
    cond do
      small_image_dimensions?(candidate.width, candidate.height) ->
        "small_dimensions"

      implausible_aspect_ratio?(candidate.width, candidate.height) ->
        "implausible_aspect_ratio"

      marker = decorative_marker(candidate) ->
        "decorative_marker:#{marker}"

      true ->
        Map.get(candidate, :rejected)
    end
  end

  @spec image_candidate_score(image_candidate()) :: integer()
  defp image_candidate_score(candidate) do
    candidate.base_score +
      dimension_score(candidate.width, candidate.height) +
      alt_score(candidate.alt) +
      url_quality_score(candidate.url)
  end

  @spec dimension_score(pos_integer() | nil, pos_integer() | nil) :: integer()
  defp dimension_score(width, height) when is_integer(width) and is_integer(height) do
    cond do
      width >= 900 and height >= 450 -> 34
      width >= 640 and height >= 320 -> 28
      width >= 300 and height >= 150 -> 18
      true -> 0
    end
  end

  defp dimension_score(_width, _height), do: 0

  @spec alt_score(String.t() | nil) :: integer()
  defp alt_score(alt) when is_binary(alt) do
    if decorative_marker_text?(alt), do: 0, else: 8
  end

  defp alt_score(_alt), do: 0

  @spec url_quality_score(String.t() | nil) :: integer()
  defp url_quality_score(url) when is_binary(url) do
    path = url |> URI.parse() |> Map.get(:path) |> to_string() |> String.downcase()

    cond do
      String.contains?(path, "hero") -> 8
      String.contains?(path, "article") -> 6
      String.contains?(path, "story") -> 6
      String.contains?(path, "news") -> 4
      true -> 0
    end
  rescue
    _ -> 0
  end

  defp url_quality_score(_url), do: 0

  @spec small_image_dimensions?(pos_integer() | nil, pos_integer() | nil) :: boolean()
  defp small_image_dimensions?(width, height) when is_integer(width) and is_integer(height),
    do: width < 160 or height < 90

  defp small_image_dimensions?(_width, _height), do: false

  @spec implausible_aspect_ratio?(pos_integer() | nil, pos_integer() | nil) :: boolean()
  defp implausible_aspect_ratio?(width, height)
       when is_integer(width) and is_integer(height) and height > 0 do
    ratio = width / height
    ratio < 0.4 or ratio > 4.0
  end

  defp implausible_aspect_ratio?(_width, _height), do: false

  @spec decorative_container_image_urls(Floki.html_tree(), String.t() | nil) :: map()
  defp decorative_container_image_urls(document, page_url) do
    @decorative_container_selectors
    |> Enum.flat_map(&decorative_container_selector_urls(document, &1, page_url))
    |> Map.new()
  end

  @spec decorative_container_selector_urls(
          Floki.html_tree(),
          {String.t(), String.t()},
          String.t() | nil
        ) :: [{String.t(), String.t()}]
  defp decorative_container_selector_urls(document, {selector, reason}, page_url) do
    document
    |> Floki.find(selector)
    |> Enum.flat_map(&decorative_container_node_url(&1, page_url, reason))
  end

  @spec decorative_container_node_url(Floki.html_node(), String.t() | nil, String.t()) ::
          [{String.t(), String.t()}]
  defp decorative_container_node_url(node, page_url, reason) do
    url =
      node
      |> attrs_map()
      |> image_src()
      |> normalize_url(page_url, :image)

    if url, do: [{url, reason}], else: []
  end

  @spec reject_decorative_container(image_candidate(), map()) :: image_candidate()
  defp reject_decorative_container(
         %{source_kind: :document, url: url} = candidate,
         decorative_urls
       )
       when is_binary(url) do
    case Map.get(decorative_urls, url) do
      nil -> candidate
      reason -> Map.put(candidate, :rejected, reason)
    end
  end

  defp reject_decorative_container(candidate, _decorative_urls), do: candidate

  @spec decorative_marker(image_candidate()) :: String.t() | nil
  defp decorative_marker(candidate) do
    [
      Map.get(candidate, :marker_text),
      Map.get(candidate, :url)
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.find_value(&decorative_marker_from_text/1)
  end

  @spec decorative_marker_text?(String.t()) :: boolean()
  defp decorative_marker_text?(text), do: not is_nil(decorative_marker_from_text(text))

  @spec decorative_marker_from_text(String.t()) :: String.t() | nil
  defp decorative_marker_from_text(text) do
    text
    |> marker_tokens()
    |> Enum.find(&MapSet.member?(@decorative_image_markers, &1))
  end

  @spec marker_tokens(String.t()) :: [String.t()]
  defp marker_tokens(text) do
    text
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
    |> String.downcase()
    |> then(&Regex.scan(~r/[[:alnum:]]+/u, &1))
    |> List.flatten()
  end

  @spec image_marker_text(map(), String.t()) :: String.t()
  defp image_marker_text(attrs, selector) do
    [
      selector,
      attrs["class"],
      attrs["id"],
      attrs["role"],
      attrs["aria-label"],
      attrs["title"],
      attrs["src"],
      attrs["data-src"],
      attrs["data-original"],
      attrs["data-lazy-src"],
      attrs["srcset"]
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end

  @spec dedupe_image_candidates([image_candidate()]) :: [image_candidate()]
  defp dedupe_image_candidates(candidates) do
    candidates
    |> Enum.group_by(&image_candidate_key/1)
    |> Enum.map(fn {_key, group} -> best_image_candidate(group) end)
    |> Enum.sort_by(&image_candidate_rank/1)
  end

  @spec image_candidate_key(image_candidate()) :: String.t()
  defp image_candidate_key(%{url: url}) when is_binary(url), do: "url:#{url}"
  defp image_candidate_key(%{raw_url: raw_url}) when is_binary(raw_url), do: "raw:#{raw_url}"
  defp image_candidate_key(candidate), do: "candidate:#{:erlang.phash2(candidate)}"

  @spec best_image_candidate([image_candidate()]) :: image_candidate()
  defp best_image_candidate(candidates) do
    Enum.max_by(candidates, &best_image_candidate_rank/1)
  end

  @spec best_image_candidate_rank(image_candidate()) :: {integer(), integer()}
  defp best_image_candidate_rank(%{rejected: rejected, score: score}) when is_nil(rejected),
    do: {1, score || 0}

  defp best_image_candidate_rank(candidate), do: {0, Map.get(candidate, :base_score, 0)}

  @spec image_candidate_rank(image_candidate()) :: {integer(), integer()}
  defp image_candidate_rank(%{rejected: rejected, score: score}) when is_nil(rejected),
    do: {0, -(score || 0)}

  defp image_candidate_rank(candidate), do: {1, -Map.get(candidate, :base_score, 0)}

  @spec select_ranked_image([image_candidate()]) :: image_selection()
  defp select_ranked_image(candidates) do
    selected =
      Enum.find(candidates, fn candidate ->
        is_nil(Map.get(candidate, :rejected)) and
          Map.get(candidate, :score, 0) >= @image_min_score
      end)

    %{selected: selected, candidates: candidates}
  end

  @spec image_selection_audit(image_selection()) :: map() | nil
  defp image_selection_audit(%{candidates: []}), do: nil

  defp image_selection_audit(%{selected: selected, candidates: candidates}) do
    %{
      "selected" => image_candidate_audit(selected),
      "candidates" =>
        candidates
        |> Enum.take(@image_audit_limit)
        |> Enum.map(&image_candidate_audit/1)
        |> Enum.reject(&is_nil/1)
    }
  end

  @spec image_candidate_audit(image_candidate() | nil) :: map() | nil
  defp image_candidate_audit(nil), do: nil

  defp image_candidate_audit(candidate) do
    %{}
    |> put_unless_empty("url", Map.get(candidate, :url))
    |> put_unless_empty("raw_url", audit_raw_url(candidate))
    |> put_unless_empty("source", Map.get(candidate, :source))
    |> put_unless_empty("selector", Map.get(candidate, :selector))
    |> put_unless_empty("score", Map.get(candidate, :score))
    |> put_unless_empty("rejected", Map.get(candidate, :rejected))
    |> put_unless_empty("width", Map.get(candidate, :width))
    |> put_unless_empty("height", Map.get(candidate, :height))
  end

  @spec audit_raw_url(image_candidate()) :: String.t() | nil
  defp audit_raw_url(%{url: url, raw_url: raw_url}) when is_binary(url) and url == raw_url,
    do: nil

  defp audit_raw_url(%{raw_url: raw_url}), do: raw_url
  defp audit_raw_url(_candidate), do: nil

  @spec image_src(map()) :: String.t() | nil
  defp image_src(attrs) do
    first_present([
      Map.get(attrs, "src"),
      Map.get(attrs, "data-src"),
      Map.get(attrs, "data-original"),
      Map.get(attrs, "data-lazy-src"),
      attrs |> Map.get("srcset") |> srcset_url()
    ])
  end

  @spec srcset_url(String.t() | nil) :: String.t() | nil
  defp srcset_url(nil), do: nil

  defp srcset_url(srcset) do
    srcset
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn entry ->
      case String.split(entry) do
        [url, width | _] -> {url, srcset_width(width)}
        [url] -> {url, 0}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.max_by(&elem(&1, 1), fn -> nil end)
    |> case do
      {url, _width} -> url
      nil -> nil
    end
  end

  @spec srcset_width(String.t()) :: non_neg_integer()
  defp srcset_width(width) do
    width
    |> String.trim_trailing("w")
    |> String.to_integer()
  rescue
    _ -> 0
  end

  @spec dimension(term()) :: pos_integer() | nil
  defp dimension(nil), do: nil

  defp dimension(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.trim_trailing("px")
    |> String.to_integer()
  rescue
    _ -> nil
  end

  @spec first_labelled([{String.t(), String.t() | nil}]) :: {String.t() | nil, String.t() | nil}
  defp first_labelled(candidates) do
    Enum.find_value(candidates, {nil, nil}, fn {source, value} ->
      if present?(value), do: {value, source}
    end)
  end

  @spec labelled_fallback(
          {String.t() | nil, String.t() | nil},
          term(),
          String.t(),
          keyword()
        ) :: {String.t() | nil, String.t() | nil}
  defp labelled_fallback({value, source}, fallback, fallback_source, opts) do
    if present?(value) do
      {value, source}
    else
      case clean_text(fallback, opts) do
        nil -> {value, source}
        clean -> {clean, fallback_source}
      end
    end
  end

  @spec meta_tags(Floki.html_tree()) :: [map()]
  defp meta_tags(scope) do
    scope
    |> Floki.find("meta")
    |> Enum.map(&attrs_map/1)
  end

  @spec link_tags(Floki.html_tree()) :: [map()]
  defp link_tags(scope) do
    scope
    |> Floki.find("link")
    |> Enum.map(&attrs_map/1)
  end

  @spec attrs_map(Floki.html_node()) :: map()
  defp attrs_map({_tag, attrs, _children}) when is_list(attrs) do
    Map.new(attrs, fn {key, value} -> {String.downcase(to_string(key)), to_string(value)} end)
  end

  defp attrs_map(_node), do: %{}

  @spec meta_content([map()], String.t(), String.t()) :: String.t() | nil
  defp meta_content(metas, key, wanted) do
    Enum.find_value(metas, fn attrs ->
      if attrs |> Map.get(key) |> normalize_key() == wanted do
        clean_text(Map.get(attrs, "content"), max: max_length_for(wanted))
      end
    end)
  end

  @spec dc_meta_content([map()], String.t()) :: String.t() | nil
  defp dc_meta_content(metas, name) do
    [
      meta_content(metas, "name", "dc.#{name}"),
      meta_content(metas, "name", "dcterms.#{name}"),
      meta_content(metas, "property", "dc:#{name}"),
      meta_content(metas, "property", "dcterms:#{name}")
    ]
    |> first_present()
  end

  @spec dc_meta_values([map()], String.t()) :: [String.t()]
  defp dc_meta_values(metas, name) do
    [
      meta_values(metas, "name", "dc.#{name}"),
      meta_values(metas, "name", "dcterms.#{name}"),
      meta_values(metas, "property", "dc:#{name}"),
      meta_values(metas, "property", "dcterms:#{name}")
    ]
    |> List.flatten()
  end

  @spec meta_values([map()], String.t(), String.t()) :: [String.t()]
  defp meta_values(metas, key, wanted) do
    metas
    |> Enum.flat_map(fn attrs ->
      if attrs |> Map.get(key) |> normalize_key() == wanted do
        [Map.get(attrs, "content")]
      else
        []
      end
    end)
    |> Enum.filter(&is_binary/1)
  end

  @spec microdata_value(Floki.html_tree(), [String.t()], :text | :date | :image | :url) ::
          String.t() | nil
  defp microdata_value(document, props, kind) do
    document
    |> microdata_values(props, kind)
    |> first_present()
  end

  @spec microdata_values(Floki.html_tree(), [String.t()], :text | :date | :image | :url) :: [
          String.t()
        ]
  defp microdata_values(document, props, kind) do
    props = MapSet.new(props)

    document
    |> Floki.find("[itemprop]")
    |> Enum.flat_map(&microdata_node_values(&1, props, kind))
  end

  @spec microdata_node_values(
          Floki.html_node(),
          MapSet.t(String.t()),
          :text | :date | :image | :url
        ) ::
          [String.t()]
  defp microdata_node_values(node, props, kind) do
    attrs = attrs_map(node)

    matches? =
      attrs
      |> Map.get("itemprop", "")
      |> String.split()
      |> Enum.any?(&MapSet.member?(props, &1))

    if matches? do
      node
      |> microdata_node_value(kind)
      |> List.wrap()
      |> Enum.filter(&is_binary/1)
    else
      []
    end
  end

  @spec microdata_node_value(Floki.html_node(), :text | :date | :image | :url) :: String.t() | nil
  defp microdata_node_value(node, :date) do
    attrs = attrs_map(node)

    first_present([
      Map.get(attrs, "content"),
      Map.get(attrs, "datetime"),
      Floki.text(node, sep: " ")
    ])
  end

  defp microdata_node_value(node, :image) do
    attrs = attrs_map(node)

    first_present([
      Map.get(attrs, "src"),
      Map.get(attrs, "data-src"),
      Map.get(attrs, "content"),
      Map.get(attrs, "href"),
      Floki.text(node, sep: " ")
    ])
  end

  defp microdata_node_value(node, :url) do
    attrs = attrs_map(node)

    first_present([Map.get(attrs, "href"), Map.get(attrs, "content"), Floki.text(node, sep: " ")])
  end

  defp microdata_node_value(node, :text) do
    attrs = attrs_map(node)

    first_present([
      Map.get(attrs, "content"),
      Map.get(attrs, "datetime"),
      Floki.text(node, sep: " ")
    ])
  end

  @spec microdata_author(Floki.html_tree()) :: String.t() | nil
  defp microdata_author(document) do
    document
    |> Floki.find("[itemprop~=author], [itemprop~=creator]")
    |> Enum.find_value(&microdata_author_node/1)
  end

  @spec microdata_article_body(Floki.html_tree()) :: String.t() | nil
  defp microdata_article_body(document) do
    document
    |> Floki.find("[itemprop~=articleBody]")
    |> Enum.map(&readable_text([&1]))
    |> Enum.join(" ")
    |> collapse_whitespace()
    |> blank_to_nil()
  end

  @spec microdata_author_node(Floki.html_node()) :: String.t() | nil
  defp microdata_author_node(node) do
    [
      node
      |> Floki.find("[itemprop~=name]")
      |> Enum.find_value(&microdata_node_value(&1, :text)),
      microdata_node_value(node, :text)
    ]
    |> first_present()
  end

  @spec canonical_url([map()]) :: String.t() | nil
  defp canonical_url(links) do
    Enum.find_value(links, fn attrs ->
      rels =
        attrs
        |> Map.get("rel", "")
        |> String.downcase()
        |> String.split()

      if "canonical" in rels, do: Map.get(attrs, "href")
    end)
  end

  @spec oembed_url([map()], String.t() | nil) :: String.t() | nil
  defp oembed_url(links, page_url) do
    Enum.find_value(links, fn attrs ->
      rels =
        attrs
        |> Map.get("rel", "")
        |> String.downcase()
        |> String.split()

      type = attrs |> Map.get("type", "") |> String.downcase()

      if "alternate" in rels and String.contains?(type, "application/json+oembed") do
        attrs
        |> Map.get("href")
        |> normalize_url(page_url, :page)
      end
    end)
  end

  @spec oembed_header_url(map(), String.t()) :: String.t() | nil
  defp oembed_header_url(headers, page_url) do
    headers
    |> header_values("link")
    |> Enum.find_value(fn header ->
      header
      |> split_link_header()
      |> Enum.find_value(&oembed_link_header_url(&1, page_url))
    end)
  end

  @spec split_link_header(String.t()) :: [String.t()]
  defp split_link_header(header) do
    {entries, current, _in_quote?, _in_angle?} =
      header
      |> String.graphemes()
      |> Enum.reduce({[], "", false, false}, fn
        "\"", {entries, current, in_quote?, in_angle?} ->
          {entries, current <> "\"", not in_quote?, in_angle?}

        "<", {entries, current, false, _in_angle?} ->
          {entries, current <> "<", false, true}

        ">", {entries, current, false, _in_angle?} ->
          {entries, current <> ">", false, false}

        ",", {entries, current, false, false} ->
          {[current | entries], "", false, false}

        char, {entries, current, in_quote?, in_angle?} ->
          {entries, current <> char, in_quote?, in_angle?}
      end)

    [current | entries]
    |> Enum.reverse()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @spec oembed_link_header_url(String.t(), String.t()) :: String.t() | nil
  defp oembed_link_header_url(entry, page_url) do
    case Regex.run(~r/^\s*<([^>]*)>(.*)$/s, entry) do
      [_, href, params] ->
        attrs = link_header_params(params)

        rels =
          attrs
          |> Map.get("rel", "")
          |> String.downcase()
          |> String.split()

        type = attrs |> Map.get("type", "") |> String.downcase()

        if "alternate" in rels and String.contains?(type, "application/json+oembed") do
          normalize_url(href, page_url, :page)
        end

      _ ->
        nil
    end
  end

  @spec link_header_params(String.t()) :: map()
  defp link_header_params(params) do
    params
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(fn
      "" ->
        []

      param ->
        case String.split(param, "=", parts: 2) do
          [key, value] -> [{String.downcase(String.trim(key)), unquote_header_value(value)}]
          _ -> []
        end
    end)
    |> Map.new()
  end

  @spec unquote_header_value(String.t()) :: String.t()
  defp unquote_header_value(value) do
    value = String.trim(value)

    if String.starts_with?(value, "\"") and String.ends_with?(value, "\"") and
         String.length(value) >= 2 do
      String.slice(value, 1, String.length(value) - 2)
    else
      value
    end
  end

  @spec json_ld_candidates(Floki.html_tree()) :: [map()]
  defp json_ld_candidates(scope) do
    scope
    |> Floki.find("script")
    |> Enum.filter(&json_ld_script?/1)
    |> Enum.flat_map(&decode_json_ld_script/1)
    |> Enum.flat_map(&flatten_json_ld/1)
    |> Enum.filter(&is_map/1)
    |> Enum.sort_by(&json_ld_rank/1)
  end

  @spec json_ld_script?(Floki.html_node()) :: boolean()
  defp json_ld_script?(node) do
    node
    |> attrs_map()
    |> Map.get("type", "")
    |> String.downcase()
    |> String.contains?("application/ld+json")
  end

  @spec decode_json_ld_script(Floki.html_node()) :: [term()]
  defp decode_json_ld_script(node) do
    text = Floki.text(node, js: true)

    case Jason.decode(text) do
      {:ok, value} -> [value]
      {:error, _reason} -> []
    end
  end

  @spec flatten_json_ld(term()) :: [term()]
  defp flatten_json_ld(values) when is_list(values), do: Enum.flat_map(values, &flatten_json_ld/1)

  defp flatten_json_ld(%{} = map) do
    graph =
      case Map.get(map, "@graph") do
        values when is_list(values) -> Enum.flat_map(values, &flatten_json_ld/1)
        value when is_map(value) -> flatten_json_ld(value)
        _ -> []
      end

    [map | graph]
  end

  defp flatten_json_ld(_value), do: []

  @spec json_ld_rank(map()) :: non_neg_integer()
  defp json_ld_rank(map) do
    types =
      map
      |> Map.get("@type")
      |> List.wrap()
      |> Enum.map(&to_string/1)

    if Enum.any?(types, &MapSet.member?(@json_ld_preferred_types, &1)), do: 0, else: 1
  end

  @spec json_ld_value([map()], [String.t()]) :: String.t() | nil
  defp json_ld_value(candidates, paths) do
    Enum.find_value(candidates, fn candidate ->
      Enum.find_value(paths, &get_path(candidate, &1))
    end)
  end

  @spec json_ld_article_body([map()]) :: String.t() | nil
  defp json_ld_article_body(candidates) do
    Enum.find_value(candidates, fn candidate ->
      [
        "articleBody",
        "text",
        "reviewBody"
      ]
      |> Enum.find_value(fn path ->
        candidate
        |> get_raw_path(path)
        |> json_ld_scalar()
        |> clean_text(max: @max_content_text_length)
      end)
    end)
  end

  @spec json_ld_values([map()], [String.t()]) :: [String.t()]
  defp json_ld_values(candidates, paths) do
    Enum.flat_map(candidates, fn candidate ->
      Enum.flat_map(paths, fn path ->
        candidate
        |> get_raw_path(path)
        |> json_ld_scalars()
      end)
    end)
  end

  @spec json_ld_image_alt([map()]) :: String.t() | nil
  defp json_ld_image_alt(candidates) do
    Enum.find_value(candidates, fn candidate ->
      candidate
      |> Map.get("image")
      |> image_alt_value()
    end)
  end

  @spec image_alt_value(term()) :: String.t() | nil
  defp image_alt_value(values) when is_list(values),
    do: Enum.find_value(values, &image_alt_value/1)

  defp image_alt_value(%{} = value) do
    ["caption", "name", "description", "alternateName"]
    |> Enum.find_value(fn key -> value |> Map.get(key) |> json_ld_scalar() end)
    |> clean_text(max: @max_title_length)
  end

  defp image_alt_value(_value), do: nil

  @spec get_path(map(), String.t()) :: String.t() | nil
  defp get_path(map, path) do
    map
    |> get_raw_path(path)
    |> json_ld_scalar()
    |> clean_text(max: @max_description_length)
  end

  @spec get_raw_path(map(), String.t()) :: term()
  defp get_raw_path(map, path) do
    path
    |> String.split(".")
    |> Enum.reduce(map, &json_ld_step/2)
  end

  @spec json_ld_step(String.t(), term()) :: term()
  defp json_ld_step(key, values) when is_list(values) do
    values
    |> Enum.flat_map(fn value ->
      case json_ld_step(key, value) do
        nested when is_list(nested) -> nested
        nil -> []
        nested -> [nested]
      end
    end)
  end

  defp json_ld_step(key, %{} = map), do: Map.get(map, key)
  defp json_ld_step(_key, _value), do: nil

  # JSON-LD lets any value be a bare string, an object that names itself, or a
  # list of either — `"author": "Ada"`, `"author": {"@type": "Person", "name":
  # "Ada"}` and `"author": [{...}, {...}]` are all valid and all appear in the
  # wild. Reducing them to one string here is what keeps every caller from having
  # to know that.
  @spec json_ld_scalar(term()) :: String.t() | nil
  defp json_ld_scalar(value) when is_binary(value), do: value
  defp json_ld_scalar(value) when is_number(value), do: to_string(value)

  # `@id` is deliberately absent: it is a URI identifying the node, never a label
  # for it, and falling back to it put strings like
  # `https://tecnoblog.net/#/schema/person/188268…` where a byline belongs.
  defp json_ld_scalar(%{} = value) do
    ["name", "@value", "headline"]
    |> Enum.find_value(fn key -> value |> Map.get(key) |> json_ld_scalar() end)
  end

  defp json_ld_scalar(value) when is_list(value),
    do: Enum.find_value(value, &json_ld_scalar/1)

  defp json_ld_scalar(_value), do: nil

  @spec json_ld_scalars(term()) :: [String.t()]
  defp json_ld_scalars(values) when is_list(values) do
    Enum.flat_map(values, &json_ld_scalars/1)
  end

  defp json_ld_scalars(value) do
    case json_ld_scalar(value) do
      nil -> []
      scalar -> [scalar]
    end
  end

  @spec split_tag_value(term()) :: [String.t()]
  defp split_tag_value(value) when is_binary(value) do
    value
    |> String.split([",", ";", "|"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_tag_value(_value), do: []

  @spec maybe_merge_oembed(metadata(), String.t() | nil, String.t()) :: metadata()
  defp maybe_merge_oembed(metadata, nil, _page_url), do: metadata

  defp maybe_merge_oembed(metadata, oembed_url, page_url) do
    if complete_enough?(metadata) do
      metadata
    else
      merge_oembed_metadata(metadata, oembed_url, page_url)
    end
  end

  @spec merge_oembed_metadata(metadata(), String.t(), String.t()) :: metadata()
  defp merge_oembed_metadata(metadata, oembed_url, page_url) do
    case fetch_oembed(oembed_url, page_url) do
      {:ok, oembed} ->
        Map.merge(oembed, metadata, fn _key, oembed_value, value -> value || oembed_value end)

      {:error, _reason} ->
        metadata
    end
  end

  @spec fetch_oembed(String.t(), String.t()) :: {:ok, metadata()} | {:error, atom()}
  defp fetch_oembed(url, page_url) do
    with {:ok, body, _final_url, headers, _status} <- fetch_resource(url, :json, []),
         true <- json_content?(first_header(headers, "content-type")),
         {:ok, data} <- Jason.decode(body) do
      metadata =
        %{}
        |> put_clean(:title, Map.get(data, "title"))
        |> put_clean(:site_name, Map.get(data, "provider_name"))
        |> put_url(:url, page_url, page_url, :page)
        |> put_url(:image, Map.get(data, "thumbnail_url"), page_url, :image)

      ensure_useful_metadata(metadata)
    else
      false -> {:error, :not_json}
      {:error, %Jason.DecodeError{}} -> {:error, :parse_failed}
      {:error, reason} when is_atom(reason) -> {:error, reason}
    end
  end

  @spec ensure_useful_metadata(metadata()) :: {:ok, metadata()} | {:error, :no_metadata}
  defp ensure_useful_metadata(metadata) do
    if Enum.any?([metadata[:title], metadata[:description], metadata[:image]], &present?/1) do
      {:ok, metadata}
    else
      {:error, :no_metadata}
    end
  end

  @spec useful_scrape?(metadata(), String.t() | nil) :: boolean()
  defp useful_scrape?(metadata, excerpt) do
    match?({:ok, _metadata}, ensure_useful_metadata(metadata)) or present?(excerpt)
  end

  @spec complete_enough?(metadata()) :: boolean()
  defp complete_enough?(metadata) do
    present?(metadata[:title]) and present?(metadata[:description]) and present?(metadata[:image])
  end

  @spec put_clean(map(), atom(), term()) :: map()
  defp put_clean(map, key, value) do
    max_length =
      case key do
        :title -> @max_title_length
        :description -> @max_description_length
        :image_alt -> @max_title_length
        :site_name -> @max_site_name_length
      end

    case clean_text(value, max: max_length) do
      nil -> map
      clean -> Map.put(map, key, clean)
    end
  end

  @spec put_url(map(), atom(), term(), String.t() | nil, :page | :image) :: map()
  defp put_url(map, key, value, base_url, kind) do
    case normalize_url(value, base_url, kind) do
      nil -> map
      url -> Map.put(map, key, url)
    end
  end

  @spec normalize_url(term(), String.t() | nil, :page | :image) :: String.t() | nil
  defp normalize_url(value, base_url, kind) do
    with value when is_binary(value) <- clean_url(value),
         url when is_binary(url) <- absolute_http_url(value, base_url),
         true <- String.length(url) <= @max_url_length,
         :ok <- maybe_guard_preview_url(url, kind) do
      url
    else
      _ -> nil
    end
  end

  @spec maybe_guard_preview_url(String.t(), :page | :image) :: :ok | :error
  defp maybe_guard_preview_url(url, :image) do
    case URLGuard.check(url) do
      :ok -> :ok
      {:error, _reason} -> :error
    end
  end

  defp maybe_guard_preview_url(url, :page) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ~w(http https) and is_binary(host) -> :ok
      _ -> :error
    end
  end

  @spec absolute_http_url(String.t(), String.t() | nil) :: String.t() | nil
  defp absolute_http_url(url, base_url) do
    uri =
      case {URI.parse(url), base_url} do
        {%URI{scheme: scheme, host: host} = uri, _base}
        when scheme in ~w(http https) and is_binary(host) ->
          uri

        {%URI{scheme: nil}, base} when is_binary(base) ->
          URI.merge(base, url)

        _other ->
          nil
      end

    if uri, do: URI.to_string(uri)
  rescue
    _ -> nil
  end

  @spec clean_text(term(), keyword()) :: String.t() | nil
  defp clean_text(value, opts \\ [])

  defp clean_text(nil, _opts), do: nil

  # Total on purpose. It is fed whatever a publisher put in a meta tag or a
  # JSON-LD document, and `to_string/1` on the object one of them nests there
  # raises — which the caller then reported as a network failure, because the
  # rescue above cannot tell a malformed page from an unreachable one.
  defp clean_text(value, _opts) when not is_binary(value) and not is_number(value), do: nil

  defp clean_text(value, opts) do
    max = Keyword.get(opts, :max, @max_description_length)

    value
    |> to_string()
    |> decode_html_entities()
    |> String.replace(~r/<[^>]*>/u, "")
    |> String.replace(<<0xC2, 0xA0>>, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> blank_to_nil()
    |> truncate_text(max)
  end

  @spec clean_url(term()) :: String.t() | nil
  defp clean_url(nil), do: nil

  defp clean_url(value) do
    value
    |> to_string()
    |> decode_html_entities()
    |> String.trim()
    |> blank_to_nil()
  end

  @spec first_present([term()]) :: String.t() | nil
  defp first_present(values) do
    Enum.find_value(values, fn value ->
      case clean_text(value) do
        nil -> nil
        clean -> clean
      end
    end)
  end

  @spec present?(term()) :: boolean()
  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  @spec blank_to_nil(String.t()) :: String.t() | nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  @spec truncate_text(String.t() | nil, non_neg_integer()) :: String.t() | nil
  defp truncate_text(nil, _max), do: nil

  defp truncate_text(text, max) do
    if String.length(text) <= max do
      text
    else
      text
      |> String.graphemes()
      |> Enum.take(max)
      |> Enum.join()
      |> Kernel.<>("...")
    end
  end

  @spec normalize_key(term()) :: String.t()
  defp normalize_key(value), do: value |> to_string() |> String.downcase() |> String.trim()

  @spec max_length_for(String.t()) :: pos_integer()
  defp max_length_for(key) when key in ["og:title", "twitter:title"], do: @max_title_length

  defp max_length_for(key) when key in ["og:image:alt", "twitter:image:alt"],
    do: @max_title_length

  defp max_length_for("og:site_name"), do: @max_site_name_length
  defp max_length_for("application-name"), do: @max_site_name_length

  defp max_length_for(key) when key in ["article:section", "section", "parsely-section"],
    do: @max_section_length

  defp max_length_for(_key), do: @max_description_length

  @spec html_content?(String.t() | nil) :: boolean()
  defp html_content?(nil), do: true
  defp html_content?(""), do: true

  defp html_content?(content_type) do
    content_type = String.downcase(content_type)

    String.contains?(content_type, "text/html") or
      String.contains?(content_type, "application/xhtml")
  end

  @spec json_content?(String.t() | nil) :: boolean()
  defp json_content?(nil), do: true
  defp json_content?(""), do: true

  defp json_content?(content_type) do
    content_type = String.downcase(content_type)
    String.contains?(content_type, "application/json") or String.contains?(content_type, "+json")
  end

  @spec first_header(map(), String.t()) :: String.t() | nil
  defp first_header(headers, name) do
    case Map.get(headers, String.downcase(name)) || Map.get(headers, name) do
      [value | _] -> value
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  @spec header_values(map(), String.t()) :: [String.t()]
  defp header_values(headers, name) do
    headers
    |> Map.get(String.downcase(name), Map.get(headers, name, []))
    |> List.wrap()
    |> Enum.filter(&is_binary/1)
  end

  @spec decode_body(binary(), String.t() | nil) :: String.t()
  defp decode_body(body, content_type) when is_binary(body) do
    case charset(content_type) do
      encoding when encoding in [:utf8, :latin1] ->
        case :unicode.characters_to_binary(body, encoding, :utf8) do
          decoded when is_binary(decoded) -> decoded
          _ -> fallback_decode_body(body)
        end

      _ ->
        fallback_decode_body(body)
    end
  end

  defp decode_body(body, _content_type), do: to_string(body)

  @spec fallback_decode_body(binary()) :: String.t()
  defp fallback_decode_body(body) do
    if String.valid?(body) do
      body
    else
      :unicode.characters_to_binary(body, :latin1, :utf8)
    end
  end

  @spec charset(String.t() | nil) :: :utf8 | :latin1 | nil
  defp charset(nil), do: nil

  defp charset(content_type) do
    case Regex.run(~r/charset\s*=\s*"?([^";\s]+)"?/i, content_type) do
      [_, value] ->
        case value |> String.downcase() |> String.replace("_", "-") do
          value when value in ["utf-8", "utf8"] -> :utf8
          value when value in ["iso-8859-1", "latin1", "latin-1", "us-ascii"] -> :latin1
          _ -> nil
        end

      nil ->
        nil
    end
  end

  @entity_map %{
    "amp" => "&",
    "apos" => "'",
    "copy" => "©",
    "gt" => ">",
    "hellip" => "…",
    "laquo" => "«",
    "ldquo" => "“",
    "lsquo" => "‘",
    "lt" => "<",
    "mdash" => "—",
    "nbsp" => " ",
    "ndash" => "–",
    "quot" => "\"",
    "raquo" => "»",
    "rdquo" => "”",
    "reg" => "®",
    "rsquo" => "’",
    "trade" => "™"
  }

  @spec decode_html_entities(String.t()) :: String.t()
  defp decode_html_entities(text) do
    text = Regex.replace(~r/&#x([0-9a-fA-F]+);/, text, fn _match, hex -> codepoint(hex, 16) end)
    text = Regex.replace(~r/&#([0-9]+);/, text, fn _match, int -> codepoint(int, 10) end)

    Regex.replace(~r/&([a-zA-Z][a-zA-Z0-9]+);/, text, fn match, name ->
      Map.get(@entity_map, String.downcase(name), match)
    end)
  end

  @spec codepoint(String.t(), 10 | 16) :: String.t()
  defp codepoint(value, base) do
    value
    |> String.to_integer(base)
    |> List.wrap()
    |> List.to_string()
  rescue
    _ -> ""
  end
end
