defmodule RetroHexChat.Bots.Capabilities.RSS.FeedParser do
  @moduledoc """
  Parses RSS 2.0 and Atom feed XML into a list of items.
  Uses Erlang's `:xmerl` library (stdlib, zero external deps).
  """

  @type feed_item :: %{
          title: String.t(),
          link: String.t(),
          published: String.t() | nil
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
          true -> {:error, "Unknown feed format (expected RSS 2.0 or Atom)"}
        end

      {:error, reason} ->
        {:error, "XML parse error: #{inspect(reason)}"}
    end
  end

  # ── XML Parsing ──

  @spec safe_xml_parse(String.t()) :: {:ok, tuple()} | {:error, term()}
  defp safe_xml_parse(xml_string) do
    charlist = String.to_charlist(xml_string)
    # Use apply to avoid compile-time warning about xmerl not being loaded yet
    {doc, _rest} = apply(:xmerl_scan, :string, [charlist, [quiet: true]])
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
    %{
      title: child_text(item, :title) || "(no title)",
      link: child_text(item, :link) || "",
      published: child_text(item, :pubDate)
    }
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
    %{
      title: child_text(entry, :title) || "(no title)",
      link: atom_link(entry) || "",
      published: child_text(entry, :published) || child_text(entry, :updated)
    }
  end

  @spec atom_link(tuple()) :: String.t() | nil
  defp atom_link(entry) do
    link_el = find_child(entry, :link)

    if link_el do
      get_attribute(link_el, :href)
    end
  end

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
