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

  # A ceiling, not a budget: high enough that no real page is cut short, low
  # enough that a hostile or runaway response cannot exhaust the node.
  @max_body_size 4_000_000
  @max_oembed_size 64_000
  @max_title_length 200
  @max_description_length 500
  @max_site_name_length 120
  @max_url_length 2_000
  @max_redirects 3

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
         {:ok, metadata, sources, oembed_url} <- metadata_from_document(document, final_url) do
      oembed_url = oembed_url || oembed_header_url(headers, final_url)

      metadata
      |> maybe_merge_oembed(oembed_url, final_url)
      |> ensure_useful_metadata()
      |> case do
        {:ok, metadata} ->
          {:ok, build_scrape(metadata, sources, document, final_url, headers, status)}

        # `ensure_useful_metadata/1` has exactly one failure: the page said
        # nothing about itself. Whether that is a page with nothing on it or a
        # wall standing in front of one is decided here.
        {:error, :no_metadata} ->
          {:error, empty_page_reason(html, headers)}
      end
    else
      false -> {:error, :not_html}
      {:not_modified} -> {:not_modified}
      {:error, reason} -> {:error, reason}
    end
  rescue
    exception ->
      # A page that breaks the extractor and a host that will not answer are two
      # different problems, and both used to arrive as a bare `:fetch_failed`.
      # That opacity hid a real bug for a whole afternoon: publishers nest objects
      # where the schema says string, `to_string/1` raised on them, and the result
      # was reported as an unreachable site.
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
          Floki.html_tree(),
          String.t(),
          map(),
          pos_integer()
        ) :: Client.scrape()
  defp build_scrape(metadata, sources, document, final_url, headers, status) do
    scope = head_scope(document)
    metas = meta_tags(scope)
    json_ld = json_ld_candidates(scope)
    {content_text, truncated?, strategy} = extract_content(document)
    sources = if content_text, do: Map.put(sources, "content_text", strategy), else: sources

    %{
      metadata: metadata,
      final_url: final_url,
      http_status: status,
      content_type: first_header(headers, "content-type"),
      etag: first_header(headers, "etag"),
      last_modified: first_header(headers, "last-modified"),
      author: author(metas, json_ld),
      published_at: published_at(metas, json_ld, document),
      lang: lang(document, metas, json_ld),
      content_text: content_text,
      content_text_truncated: truncated?,
      raw_metadata: raw_metadata(metas, json_ld, sources)
    }
  end

  # Generous, because the row is written once and read for four months. A page
  # long enough to hit this is a transcript or a book chapter, and the opening
  # 200k characters of one still answer far more than a truncation flag alone.
  @max_content_text_length 200_000

  @boilerplate ~w(script style noscript nav header footer aside form template iframe svg)

  @doc """
  The page's own words, with the furniture removed.

  Prefers whatever the document itself calls its main content — `<article>`, then
  `<main>` — and falls back to the body, because a page that names nothing still
  has an article in it somewhere and a partly-noisy answer beats none. Which of
  the three was used is recorded under `raw_metadata["sources"]["content_text"]`,
  so a later reader can weigh it.
  """
  @spec extract_content(Floki.html_tree()) :: {String.t() | nil, boolean(), String.t()}
  def extract_content(document) do
    {scope, strategy} = content_scope(document)

    {text, truncated?} =
      @boilerplate
      |> Enum.reduce(scope, &Floki.filter_out(&2, &1))
      |> Floki.text(sep: " ")
      |> collapse_whitespace()
      |> cap_content()

    {text, truncated?, strategy}
  rescue
    _ -> {nil, false, "none"}
  end

  @spec content_scope(Floki.html_tree()) :: {Floki.html_tree(), String.t()}
  defp content_scope(document) do
    Enum.find_value(
      [{"article", "article"}, {"main", "main"}, {"body", "body"}],
      {document, "document"},
      fn {selector, strategy} ->
        case Floki.find(document, selector) do
          [] -> nil
          found -> {found, strategy}
        end
      end
    )
  end

  @spec collapse_whitespace(String.t()) :: String.t()
  defp collapse_whitespace(text), do: text |> String.split() |> Enum.join(" ")

  @spec cap_content(String.t()) :: {String.t() | nil, boolean()}
  defp cap_content(""), do: {nil, false}

  defp cap_content(text) do
    if String.length(text) > @max_content_text_length do
      {String.slice(text, 0, @max_content_text_length), true}
    else
      {text, false}
    end
  end

  # `twitter:creator` is deliberately absent. It is as often the publication's own
  # handle as the writer's — Engadget puts `@engadget` there — so using it would
  # attribute an article to whoever runs the account. A missing byline is better
  # than a wrong one.
  @spec author([map()], [map()]) :: String.t() | nil
  defp author(metas, json_ld) do
    [
      meta_content(metas, "property", "article:author"),
      meta_content(metas, "property", "og:article:author"),
      meta_content(metas, "name", "author"),
      meta_content(metas, "name", "byl"),
      json_ld_value(json_ld, ["author.name", "creator.name", "author"])
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
      json_ld_value(json_ld, ["datePublished", "dateCreated", "uploadDate"]),
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

  # Everything the page said that did not earn a column of its own, plus which
  # standard each column came from. One place to look when a stored title is
  # wrong, and no need to re-fetch the page to find out why.
  @spec raw_metadata([map()], [map()], map()) :: map()
  defp raw_metadata(metas, json_ld, sources) do
    %{}
    |> put_unless_empty("sources", sources)
    |> put_unless_empty("og", namespaced_metas(metas, "property", "og:"))
    |> put_unless_empty("article", namespaced_metas(metas, "property", "article:"))
    |> put_unless_empty("twitter", namespaced_metas(metas, "name", "twitter:"))
    |> put_unless_empty("json_ld", json_ld)
  end

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

  @spec put_unless_empty(map(), String.t(), map() | list()) :: map()
  defp put_unless_empty(map, _key, value) when value == %{} or value == [], do: map
  defp put_unless_empty(map, key, value), do: Map.put(map, key, value)

  @json_ld_preferred_types MapSet.new(~w(
    Article
    BlogPosting
    NewsArticle
    Product
    Recipe
    VideoObject
    WebPage
    WebSite
  ))

  @doc """
  Fetches rich preview metadata while preserving retry-relevant error detail.
  """
  @spec fetch_metadata_result(String.t()) :: {:ok, metadata()} | {:error, fetch_error()}
  def fetch_metadata_result(url) do
    case scrape(url, []) do
      {:ok, %{metadata: metadata}} -> {:ok, metadata}
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
         {:ok, metadata, _sources, _oembed_url} <- metadata_from_document(document, page_url) do
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

  @spec metadata_from_document(Floki.html_tree(), String.t() | nil) ::
          {:ok, metadata(), map(), String.t() | nil}
  defp metadata_from_document(document, page_url) do
    scope = head_scope(document)
    metas = meta_tags(scope)
    links = link_tags(scope)
    json_ld = json_ld_candidates(scope)

    {title, title_source} = title(metas, json_ld, scope)
    {description, description_source} = description(metas, json_ld)
    {site_name, site_name_source} = site_name(metas, json_ld)
    {url_value, url_source} = page_url(metas, links, page_url)
    {image, image_source} = image_url(metas, json_ld)

    metadata =
      %{}
      |> put_clean(:title, title)
      |> put_clean(:description, description)
      |> put_clean(:site_name, site_name)
      |> put_url(:url, url_value, page_url, :page)
      |> put_url(:image, image, page_url, :image)

    sources =
      %{
        "title" => title_source,
        "description" => description_source,
        "site_name" => site_name_source,
        "url" => url_source,
        "image" => image_source
      }
      |> Map.take(metadata |> Map.keys() |> Enum.map(&Atom.to_string/1))
      |> Map.reject(fn {_key, source} -> is_nil(source) end)

    {:ok, metadata, sources, oembed_url(links, page_url)}
  end

  @spec head_scope(Floki.html_tree()) :: Floki.html_tree()
  defp head_scope(document) do
    case Floki.find(document, "head") do
      [] -> document
      heads -> heads
    end
  end

  @spec title([map()], [map()], Floki.html_tree()) :: {String.t() | nil, String.t() | nil}
  defp title(metas, json_ld, scope) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:title")},
      {"twitter", meta_content(metas, "name", "twitter:title")},
      {"json_ld", json_ld_value(json_ld, ["headline", "name"])},
      {"html", scope |> Floki.find("title") |> Floki.text()}
    ])
  end

  @spec description([map()], [map()]) :: {String.t() | nil, String.t() | nil}
  defp description(metas, json_ld) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:description")},
      {"twitter", meta_content(metas, "name", "twitter:description")},
      {"json_ld", json_ld_value(json_ld, ["description"])},
      {"html", meta_content(metas, "name", "description")}
    ])
  end

  @spec site_name([map()], [map()]) :: {String.t() | nil, String.t() | nil}
  defp site_name(metas, json_ld) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:site_name")},
      {"html", meta_content(metas, "name", "application-name")},
      {"json_ld", json_ld_value(json_ld, ["publisher.name", "provider.name"])}
    ])
  end

  @spec page_url([map()], [map()], String.t() | nil) :: {String.t() | nil, String.t() | nil}
  defp page_url(metas, links, fallback) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:url")},
      {"twitter", meta_content(metas, "name", "twitter:url")},
      {"canonical", canonical_url(links)},
      {"request", fallback}
    ])
  end

  @spec image_url([map()], [map()]) :: {String.t() | nil, String.t() | nil}
  defp image_url(metas, json_ld) do
    first_labelled([
      {"og", meta_content(metas, "property", "og:image:secure_url")},
      {"og", meta_content(metas, "property", "og:image:url")},
      {"og", meta_content(metas, "property", "og:image")},
      {"twitter", meta_content(metas, "name", "twitter:image")},
      {"twitter", meta_content(metas, "name", "twitter:image:src")},
      {"json_ld", json_ld_image(json_ld)}
    ])
  end

  @spec first_labelled([{String.t(), String.t() | nil}]) :: {String.t() | nil, String.t() | nil}
  defp first_labelled(candidates) do
    Enum.find_value(candidates, {nil, nil}, fn {source, value} ->
      if present?(value), do: {value, source}
    end)
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

  @spec json_ld_image([map()]) :: String.t() | nil
  defp json_ld_image(candidates) do
    Enum.find_value(candidates, fn candidate ->
      candidate
      |> Map.get("image")
      |> image_value()
    end) || json_ld_value(candidates, ["thumbnailUrl"])
  end

  @spec image_value(term()) :: String.t() | nil
  defp image_value(value) when is_binary(value), do: value
  defp image_value(values) when is_list(values), do: Enum.find_value(values, &image_value/1)

  defp image_value(%{} = value) do
    first_present([Map.get(value, "url"), Map.get(value, "contentUrl")])
  end

  defp image_value(_value), do: nil

  @spec get_path(map(), String.t()) :: String.t() | nil
  defp get_path(map, path) do
    path
    |> String.split(".")
    |> Enum.reduce_while(map, fn key, current ->
      case current do
        %{} -> {:cont, Map.get(current, key)}
        _ -> {:halt, nil}
      end
    end)
    |> json_ld_scalar()
    |> clean_text(max: @max_description_length)
  end

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
  defp max_length_for("og:site_name"), do: @max_site_name_length
  defp max_length_for("application-name"), do: @max_site_name_length
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
