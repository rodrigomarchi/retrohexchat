defmodule RetroHexChat.Bots.Capabilities.RSS.FeedParser do
  @moduledoc """
  Parses RSS 2.0 and Atom feed XML into a list of items.
  Uses Erlang's `:xmerl` library (stdlib, zero external deps).
  """

  use Gettext, backend: RetroHexChat.Gettext

  @type feed_item :: %{
          required(:title) => String.t(),
          required(:link) => String.t(),
          # RSS <guid> / Atom <id>: the publisher's own name for the item, and
          # the only identity that stays put when a link is rewritten.
          required(:guid) => String.t() | nil,
          required(:published) => String.t() | nil,
          optional(:image_url) => String.t() | nil,
          optional(:image_alt) => String.t() | nil,
          optional(:image_source) => String.t() | nil
        }

  @typep image_info :: %{
           required(:image_url) => String.t(),
           optional(:image_alt) => String.t() | nil,
           required(:image_source) => String.t()
         }

  @type feed_info :: %{
          title: String.t() | nil,
          items: [feed_item()]
        }

  @spec parse(String.t()) :: {:ok, feed_info()} | {:error, String.t()}
  def parse(xml_string) do
    xml_string = String.trim(xml_string)

    case safe_xml_parse(xml_string) do
      {:ok, doc} ->
        cond do
          rss_feed?(doc) -> {:ok, parse_rss(doc)}
          atom_feed?(doc) -> {:ok, parse_atom(doc)}
          true -> {:error, dgettext("bots", "Unknown feed format (expected RSS 2.0 or Atom)")}
        end

      {:error, reason} ->
        {:error, dgettext("bots", "XML parse error: %{reason}", reason: inspect(reason))}
    end
  end

  # ── XML Parsing ──

  @spec safe_xml_parse(String.t()) :: {:ok, tuple()} | {:error, term()}
  defp safe_xml_parse(xml_string) do
    # Bytes, not codepoints. `String.to_charlist/1` hands xmerl a list of
    # Unicode codepoints, but xmerl reads its input as bytes and decodes them
    # according to the document's own declaration — so a codepoint above 255
    # arrives as an illegal character. Every real feed has one: a curly
    # apostrophe, an en dash, an ellipsis. This rejected all of them.
    bytes = :binary.bin_to_list(xml_string)
    # Use apply to avoid compile-time warning about xmerl not being loaded yet
    {doc, _rest} = apply(:xmerl_scan, :string, [bytes, [quiet: true]])
    {:ok, doc}
  rescue
    e -> {:error, Exception.message(e)}
  catch
    :exit, reason -> {:error, reason}
  end

  # ── Feed Type Detection ──

  @spec rss_feed?(tuple()) :: boolean()
  defp rss_feed?(doc) do
    element_name(doc) == :rss
  end

  @spec atom_feed?(tuple()) :: boolean()
  defp atom_feed?(doc) do
    element_name(doc) == :feed
  end

  # ── RSS 2.0 Parsing ──

  @spec parse_rss(tuple()) :: feed_info()
  defp parse_rss(doc) do
    channel = find_child(doc, :channel)

    title =
      if channel do
        child_text(channel, :title)
      end

    items =
      if channel do
        find_children(channel, :item) |> Enum.map(&parse_rss_item/1)
      else
        []
      end

    %{title: title, items: items}
  end

  @spec parse_rss_item(tuple()) :: feed_item()
  defp parse_rss_item(item) do
    item
    |> rss_item_image()
    |> put_item_image(%{
      title: child_text(item, :title) || dgettext("bots", "(no title)"),
      link: child_text(item, :link) || "",
      guid: child_text(item, :guid),
      published: child_text(item, :pubDate)
    })
  end

  # ── Atom Parsing ──

  @spec parse_atom(tuple()) :: feed_info()
  defp parse_atom(doc) do
    title = child_text(doc, :title)
    entries = find_children(doc, :entry) |> Enum.map(&parse_atom_entry/1)
    %{title: title, items: entries}
  end

  @spec parse_atom_entry(tuple()) :: feed_item()
  defp parse_atom_entry(entry) do
    entry
    |> atom_entry_image()
    |> put_item_image(%{
      title: child_text(entry, :title) || dgettext("bots", "(no title)"),
      link: atom_link(entry) || "",
      guid: child_text(entry, :id),
      published: child_text(entry, :published) || child_text(entry, :updated)
    })
  end

  @spec atom_link(tuple()) :: String.t() | nil
  defp atom_link(entry) do
    links = find_children(entry, :link)

    Enum.find_value(links, fn link ->
      rel = link |> get_attribute(:rel) |> normalized_attr()

      if rel in [nil, "", "alternate"] do
        get_attribute(link, :href)
      end
    end) || Enum.find_value(links, &get_attribute(&1, :href))
  end

  # ── Feed Item Images ──

  @spec rss_item_image(tuple()) :: image_info() | nil
  defp rss_item_image(item) do
    first_image([
      media_content_image(item),
      media_thumbnail_image(item),
      enclosure_image(item),
      description_image(child_text(item, :description), "description_image")
    ])
  end

  @spec atom_entry_image(tuple()) :: image_info() | nil
  defp atom_entry_image(entry) do
    first_image([
      media_content_image(entry),
      media_thumbnail_image(entry),
      atom_link_image(entry),
      description_image(child_text(entry, :summary), "summary_image"),
      description_image(child_text(entry, :content), "content_image")
    ])
  end

  @spec first_image([image_info() | nil]) :: image_info() | nil
  defp first_image(images),
    do: Enum.find(images, fn image -> match?(%{image_url: _url}, image) end)

  @spec put_item_image(image_info() | nil, feed_item()) :: feed_item()
  defp put_item_image(nil, item), do: item

  defp put_item_image(image, item) do
    item
    |> Map.put(:image_url, image.image_url)
    |> maybe_put(:image_alt, Map.get(image, :image_alt))
    |> Map.put(:image_source, image.image_source)
  end

  @spec media_content_image(tuple()) :: image_info() | nil
  defp media_content_image(parent) do
    parent
    |> find_children_by_local_name("content")
    |> Enum.find_value(fn element ->
      url = get_attribute(element, :url)

      if media_image_element?(element, url) do
        image_info(url, media_image_alt(element), "media_content")
      end
    end)
  end

  @spec media_thumbnail_image(tuple()) :: image_info() | nil
  defp media_thumbnail_image(parent) do
    parent
    |> find_children_by_local_name("thumbnail")
    |> Enum.find_value(fn element ->
      image_info(get_attribute(element, :url), media_image_alt(element), "media_thumbnail")
    end)
  end

  @spec enclosure_image(tuple()) :: image_info() | nil
  defp enclosure_image(parent) do
    parent
    |> find_children(:enclosure)
    |> Enum.find_value(fn element ->
      url = get_attribute(element, :url)

      if image_type?(get_attribute(element, :type)) or image_url?(url) do
        image_info(url, get_attribute(element, :title), "enclosure")
      end
    end)
  end

  @spec atom_link_image(tuple()) :: image_info() | nil
  defp atom_link_image(entry) do
    entry
    |> find_children(:link)
    |> Enum.find_value(fn link ->
      rel = link |> get_attribute(:rel) |> normalized_attr()
      url = get_attribute(link, :href)

      if rel in ["enclosure", "thumbnail", "image"] and
           (image_type?(get_attribute(link, :type)) or image_url?(url)) do
        image_info(url, get_attribute(link, :title), "atom_link")
      end
    end)
  end

  @spec media_image_element?(tuple(), String.t() | nil) :: boolean()
  defp media_image_element?(element, url) do
    element
    |> get_attribute(:medium)
    |> normalized_attr()
    |> Kernel.==("image") or
      image_type?(get_attribute(element, :type)) or image_url?(url)
  end

  @spec media_image_alt(tuple()) :: String.t() | nil
  defp media_image_alt(element) do
    get_attribute(element, :title) ||
      get_attribute(element, :description) ||
      get_attribute(element, :alt)
  end

  @spec description_image(String.t() | nil, String.t()) :: image_info() | nil
  defp description_image(nil, _source), do: nil

  defp description_image(html, source) do
    with true <- String.contains?(String.downcase(html), "<img"),
         {:ok, nodes} <- Floki.parse_fragment(html) do
      nodes
      |> Floki.find("img")
      |> Enum.find_value(&description_node_image(&1, source))
    else
      _other -> nil
    end
  end

  @spec description_node_image(Floki.html_node(), String.t()) :: image_info() | nil
  defp description_node_image(node, source) do
    attrs = html_attrs(node)
    image_info(html_image_src(attrs), Map.get(attrs, "alt"), source)
  end

  @spec image_info(String.t() | nil, String.t() | nil, String.t()) :: image_info() | nil
  defp image_info(url, alt, source) when is_binary(url) do
    url = String.trim(url)

    if url == "" do
      nil
    else
      %{
        image_url: url,
        image_source: source
      }
      |> maybe_put(:image_alt, clean_item_text(alt))
    end
  end

  defp image_info(_url, _alt, _source), do: nil

  @spec html_image_src(map()) :: String.t() | nil
  defp html_image_src(attrs) do
    first_present_attr([
      Map.get(attrs, "src"),
      Map.get(attrs, "data-src"),
      Map.get(attrs, "data-original"),
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

  @spec image_type?(String.t() | nil) :: boolean()
  defp image_type?(type) when is_binary(type),
    do: type |> String.downcase() |> String.starts_with?("image/")

  defp image_type?(_type), do: false

  @spec image_url?(String.t() | nil) :: boolean()
  defp image_url?(url) when is_binary(url) do
    url
    |> URI.parse()
    |> Map.get(:path)
    |> to_string()
    |> String.downcase()
    |> String.ends_with?([".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"])
  rescue
    _ -> false
  end

  defp image_url?(_url), do: false

  @spec maybe_put(map(), atom(), term()) :: map()
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @spec clean_item_text(term()) :: String.t() | nil
  defp clean_item_text(value) when is_binary(value) do
    value
    |> String.replace(~r/<[^>]*>/u, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> case do
      "" -> nil
      clean -> clean
    end
  end

  defp clean_item_text(_value), do: nil

  @spec first_present_attr([term()]) :: String.t() | nil
  defp first_present_attr(values) do
    Enum.find_value(values, fn
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> nil
          clean -> clean
        end

      _other ->
        nil
    end)
  end

  @spec normalized_attr(String.t() | nil) :: String.t() | nil
  defp normalized_attr(value) when is_binary(value),
    do: value |> String.downcase() |> String.trim()

  defp normalized_attr(_value), do: nil

  @spec html_attrs(Floki.html_node()) :: map()
  defp html_attrs({_tag, attrs, _children}) when is_list(attrs) do
    Map.new(attrs, fn {key, value} -> {String.downcase(to_string(key)), to_string(value)} end)
  end

  defp html_attrs(_node), do: %{}

  # ── xmerl Helpers ──

  @spec element_name(tuple()) :: atom()
  defp element_name({:xmlElement, name, _, _, _, _, _, _, _, _, _, _}), do: name
  defp element_name(_), do: nil

  @spec find_child(tuple(), atom()) :: tuple() | nil
  defp find_child({:xmlElement, _, _, _, _, _, _, _, content, _, _, _}, name) do
    Enum.find(content, fn
      {:xmlElement, n, _, _, _, _, _, _, _, _, _, _} -> n == name
      _ -> false
    end)
  end

  defp find_child(_, _), do: nil

  @spec find_children(tuple(), atom()) :: [tuple()]
  defp find_children({:xmlElement, _, _, _, _, _, _, _, content, _, _, _}, name) do
    Enum.filter(content, fn
      {:xmlElement, n, _, _, _, _, _, _, _, _, _, _} -> n == name
      _ -> false
    end)
  end

  defp find_children(_, _), do: []

  @spec find_children_by_local_name(tuple(), String.t()) :: [tuple()]
  defp find_children_by_local_name({:xmlElement, _, _, _, _, _, _, _, content, _, _, _}, name) do
    Enum.filter(content, fn
      {:xmlElement, _, _, _, _, _, _, _, _, _, _, _} = element ->
        local_element_name(element) == name

      _ ->
        false
    end)
  end

  defp find_children_by_local_name(_, _), do: []

  @spec local_element_name(tuple()) :: String.t() | nil
  defp local_element_name({:xmlElement, name, _, _, _, _, _, _, _, _, _, _}) do
    name
    |> Atom.to_string()
    |> String.split(":")
    |> List.last()
  end

  @spec child_text(tuple(), atom()) :: String.t() | nil
  defp child_text(parent, name) do
    child = find_child(parent, name)

    if child do
      extract_text(child)
    end
  end

  @spec extract_text(tuple()) :: String.t()
  defp extract_text({:xmlElement, _, _, _, _, _, _, _, content, _, _, _}) do
    content
    |> Enum.filter(fn
      {:xmlText, _, _, _, _, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:xmlText, _, _, _, text, _} -> to_string(text) end)
    |> Enum.join()
    |> String.trim()
  end

  defp extract_text(_), do: ""

  @spec get_attribute(tuple(), atom()) :: String.t() | nil
  defp get_attribute({:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _}, name) do
    case Enum.find(attrs, fn {:xmlAttribute, n, _, _, _, _, _, _, _, _} -> n == name end) do
      {:xmlAttribute, _, _, _, _, _, _, _, value, _} -> to_string(value)
      nil -> nil
    end
  end

  defp get_attribute(_, _), do: nil
end
