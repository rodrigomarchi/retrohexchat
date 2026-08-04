defmodule RetroHexChat.Chat.LinkPreview.HTTP do
  @moduledoc """
  HTTP implementation of the `RetroHexChat.Chat.LinkPreview` behaviour.

  The extractor is deliberately standards-led rather than scraper-led. It reads
  publisher-provided preview metadata from the document head:

    * Open Graph (`og:title`, `og:description`, `og:image`, `og:url`)
    * Twitter/X Cards (`twitter:title`, `twitter:description`, `twitter:image`)
    * Schema.org JSON-LD (`headline`, `name`, `description`, `image`)
    * HTML fallbacks (`<title>`, `meta[name=description]`, canonical link)
    * oEmbed JSON only when the page explicitly advertises a discovery link

  Every server-side URL fetch is checked by `RetroHexChat.Net.URLGuard`, including
  redirects and discovered oEmbed endpoints.
  """

  @behaviour RetroHexChat.Chat.LinkPreview

  alias RetroHexChat.Chat.LinkPreview
  alias RetroHexChat.Net.URLGuard

  @type metadata :: LinkPreview.metadata()

  @max_body_size 256_000
  @max_oembed_size 64_000
  @max_title_length 200
  @max_description_length 500
  @max_site_name_length 120
  @max_url_length 2_000
  @max_redirects 3
  @timeout_ms 5_000

  @html_accept "text/html, application/xhtml+xml;q=0.9, */*;q=0.1"
  @json_accept "application/json, application/*+json;q=0.9, */*;q=0.1"
  @user_agent "RetroHexChat-LinkPreview/1.0"
  @redirect_statuses [301, 302, 303, 307, 308]

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

  @impl true
  @spec fetch_title(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fetch_title(url) do
    case fetch_metadata(url) do
      {:ok, %{title: title}} when is_binary(title) and title != "" ->
        {:ok, html_escape(title)}

      {:ok, _metadata} ->
        {:error, :no_title}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  @spec fetch_metadata(String.t()) :: {:ok, metadata()} | {:error, atom()}
  def fetch_metadata(url) do
    with {:ok, html, final_url, headers} <- fetch_resource(url, :html),
         true <- html_content?(first_header(headers, "content-type")),
         {:ok, metadata, oembed_url} <- parse_page_metadata(html, final_url) do
      oembed_url = oembed_url || oembed_header_url(headers, final_url)

      metadata
      |> maybe_merge_oembed(oembed_url, final_url)
      |> ensure_useful_metadata()
    else
      false -> {:error, :not_html}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :fetch_failed}
  end

  @doc """
  Parses a page title from an HTML document.

  Kept for the URL Catcher title cache. New consumers should prefer
  `parse_metadata/2`.
  """
  @spec parse_title(String.t()) :: {:ok, String.t()} | {:error, :no_title}
  def parse_title(html) do
    case parse_metadata(html) do
      {:ok, %{title: title}} when is_binary(title) and title != "" ->
        {:ok, html_escape(title)}

      _ ->
        {:error, :no_title}
    end
  end

  @doc """
  Extracts standards-based preview metadata from already-fetched HTML.
  """
  @spec parse_metadata(String.t(), String.t() | nil) :: {:ok, metadata()} | {:error, atom()}
  def parse_metadata(html, page_url \\ nil) when is_binary(html) do
    with {:ok, metadata, _oembed_url} <- parse_page_metadata(html, page_url) do
      ensure_useful_metadata(metadata)
    end
  end

  @spec fetch_resource(String.t(), :html | :json) ::
          {:ok, String.t(), String.t(), map()} | {:error, atom()}
  defp fetch_resource(url, kind), do: fetch_resource(url, kind, @max_redirects)

  @spec fetch_resource(String.t(), :html | :json, non_neg_integer()) ::
          {:ok, String.t(), String.t(), map()} | {:error, atom()}
  defp fetch_resource(url, kind, redirects_left) do
    case URLGuard.fetch_target(url) do
      {:ok, target} -> fetch_resource_target(target, url, kind, redirects_left)
      {:error, _reason} -> {:error, :blocked}
    end
  end

  @spec fetch_resource_target(
          URLGuard.fetch_target(),
          String.t(),
          :html | :json,
          non_neg_integer()
        ) ::
          {:ok, String.t(), String.t(), map()} | {:error, atom()}
  defp fetch_resource_target(target, url, kind, redirects_left) do
    case request_once(target, kind) do
      {:ok, response} -> handle_resource_response(response, url, kind, redirects_left)
      {:error, _reason} -> {:error, :fetch_failed}
    end
  end

  @spec handle_resource_response(Req.Response.t(), String.t(), :html | :json, non_neg_integer()) ::
          {:ok, String.t(), String.t(), map()} | {:error, atom()}
  defp handle_resource_response(
         %{status: status, body: body, headers: headers},
         url,
         _kind,
         _redirects_left
       )
       when status in 200..299 do
    {:ok, decode_body(body, first_header(headers, "content-type")), url, headers}
  end

  defp handle_resource_response(%{status: status, headers: headers}, url, kind, redirects_left)
       when status in @redirect_statuses do
    follow_redirect(url, headers, kind, redirects_left)
  end

  defp handle_resource_response(%{status: status}, _url, _kind, _redirects_left)
       when status in 400..499 do
    {:error, :not_found}
  end

  defp handle_resource_response(_response, _url, _kind, _redirects_left),
    do: {:error, :server_error}

  @spec request_once(URLGuard.fetch_target(), :html | :json) ::
          {:ok, Req.Response.t()} | {:error, term()}
  defp request_once(target, kind) do
    Req.get(request_options(target, kind))
  end

  @spec request_options(URLGuard.fetch_target(), :html | :json) :: keyword()
  defp request_options(target, kind) do
    target
    |> base_request_options(kind)
    |> merge_request_overrides()
  end

  @spec base_request_options(URLGuard.fetch_target(), :html | :json) :: keyword()
  defp base_request_options(target, kind) do
    options = [
      url: target.url,
      headers: request_headers(kind),
      redirect: false,
      compressed: false,
      decode_body: false,
      max_retries: 0,
      connect_options: Keyword.put(target.connect_options, :timeout, @timeout_ms),
      receive_timeout: @timeout_ms,
      into: collector(kind)
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

  @spec request_overrides() :: keyword()
  defp request_overrides do
    Application.get_env(:retro_hex_chat, :link_preview_req_options, [])
  end

  @spec collector(:html | :json) :: function()
  defp collector(:html), do: &collect_limited_body(&1, &2, @max_body_size, true)
  defp collector(:json), do: &collect_limited_body(&1, &2, @max_oembed_size, false)

  @spec collect_limited_body(
          {:data, binary()},
          {Req.Request.t(), Req.Response.t()},
          pos_integer(),
          boolean()
        ) ::
          {:cont | :halt, {Req.Request.t(), Req.Response.t()}}
  defp collect_limited_body({:data, data}, {request, response}, max_size, halt_on_head?) do
    current = if is_binary(response.body), do: response.body, else: ""
    remaining = max(max_size - byte_size(current), 0)
    data = binary_part(data, 0, min(byte_size(data), remaining))
    body = current <> data
    response = %{response | body: body}

    if byte_size(body) >= max_size or (halt_on_head? and head_closed?(body)) do
      {:halt, {request, response}}
    else
      {:cont, {request, response}}
    end
  end

  @spec head_closed?(binary()) :: boolean()
  defp head_closed?(body) do
    Regex.match?(~r/<\/head\s*>/i, body)
  rescue
    _ -> false
  end

  @spec follow_redirect(String.t(), map(), :html | :json, non_neg_integer()) ::
          {:ok, String.t(), String.t(), map()} | {:error, atom()}
  defp follow_redirect(_url, _headers, _kind, 0), do: {:error, :too_many_redirects}

  defp follow_redirect(url, headers, kind, redirects_left) do
    case redirect_url(url, first_header(headers, "location")) do
      nil -> {:error, :server_error}
      next_url -> fetch_resource(next_url, kind, redirects_left - 1)
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

  @spec parse_page_metadata(String.t(), String.t() | nil) ::
          {:ok, metadata(), String.t() | nil} | {:error, atom()}
  defp parse_page_metadata(html, page_url) do
    case Floki.parse_document(String.slice(html, 0, @max_body_size)) do
      {:ok, document} ->
        scope = head_scope(document)
        metas = meta_tags(scope)
        links = link_tags(scope)
        json_ld = json_ld_candidates(scope)

        metadata =
          %{}
          |> put_clean(:title, title(metas, json_ld, scope))
          |> put_clean(:description, description(metas, json_ld))
          |> put_clean(:site_name, site_name(metas, json_ld))
          |> put_url(:url, page_url(metas, links, page_url), page_url, :page)
          |> put_url(:image, image_url(metas, json_ld), page_url, :image)

        {:ok, metadata, oembed_url(links, page_url)}

      {:error, _reason} ->
        {:error, :parse_failed}
    end
  end

  @spec head_scope(Floki.html_tree()) :: Floki.html_tree()
  defp head_scope(document) do
    case Floki.find(document, "head") do
      [] -> document
      heads -> heads
    end
  end

  @spec title([map()], [map()], Floki.html_tree()) :: String.t() | nil
  defp title(metas, json_ld, scope) do
    first_present([
      meta_content(metas, "property", "og:title"),
      meta_content(metas, "name", "twitter:title"),
      json_ld_value(json_ld, ["headline", "name"]),
      scope |> Floki.find("title") |> Floki.text()
    ])
  end

  @spec description([map()], [map()]) :: String.t() | nil
  defp description(metas, json_ld) do
    first_present([
      meta_content(metas, "property", "og:description"),
      meta_content(metas, "name", "twitter:description"),
      json_ld_value(json_ld, ["description"]),
      meta_content(metas, "name", "description")
    ])
  end

  @spec site_name([map()], [map()]) :: String.t() | nil
  defp site_name(metas, json_ld) do
    first_present([
      meta_content(metas, "property", "og:site_name"),
      meta_content(metas, "name", "application-name"),
      json_ld_value(json_ld, ["publisher.name", "provider.name"])
    ])
  end

  @spec page_url([map()], [map()], String.t() | nil) :: String.t() | nil
  defp page_url(metas, links, fallback) do
    first_present([
      meta_content(metas, "property", "og:url"),
      meta_content(metas, "name", "twitter:url"),
      canonical_url(links),
      fallback
    ])
  end

  @spec image_url([map()], [map()]) :: String.t() | nil
  defp image_url(metas, json_ld) do
    first_present([
      meta_content(metas, "property", "og:image:secure_url"),
      meta_content(metas, "property", "og:image:url"),
      meta_content(metas, "property", "og:image"),
      meta_content(metas, "name", "twitter:image"),
      meta_content(metas, "name", "twitter:image:src"),
      json_ld_image(json_ld)
    ])
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
    |> clean_text(max: @max_description_length)
  end

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
    with {:ok, body, _final_url, headers} <- fetch_resource(url, :json),
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

  @spec html_escape(String.t()) :: String.t()
  defp html_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
