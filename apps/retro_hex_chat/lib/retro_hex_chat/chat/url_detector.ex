defmodule RetroHexChat.Chat.URLDetector do
  @moduledoc """
  Detects and linkifies URLs in chat message text.

  Provides three public functions:
  - `extract_urls/1` — extracts all URLs from raw text (may contain IRC format codes)
  - `linkify/1` — converts plain text to HTML with URLs as clickable `<a>` tags
  - `linkify_html/1` — post-processes Formatter HTML to wrap URLs in `<a>` tags
  """

  alias RetroHexChat.Chat.Formatter

  @max_display_length 100

  # Greedy match: http(s):// followed by non-whitespace, non-angle-bracket chars
  @url_pattern ~r{https?://[^\s<>]+}i

  @trailing_punct ~c".!,;:?"

  # --- Public API ---

  @doc """
  Extracts all URLs from raw message text, returning them in order of appearance.

  Strips IRC format codes before detection. Handles trailing punctuation
  trimming, balanced parentheses, and balanced brackets.
  """
  @spec extract_urls(String.t()) :: [String.t()]
  def extract_urls(text) when is_binary(text) do
    text
    |> Formatter.strip()
    |> find_urls()
  end

  @doc """
  Converts plain text to HTML with URLs wrapped in `<a>` tags.

  Non-URL text is HTML-escaped. URLs get `target="_blank"`,
  `rel="noopener noreferrer"`, `class="chat-link"`, and a `title` attribute.
  URLs longer than #{@max_display_length} characters have their display text truncated.
  """
  @spec linkify(String.t()) :: String.t()
  def linkify(text) when is_binary(text) do
    linkify_text(text, &html_escape/1)
  end

  @doc """
  Post-processes Formatter HTML output to wrap URL text in `<a>` tags.

  Preserves existing `<span>` formatting. URLs are detected in the text
  content between HTML tags and wrapped in anchor elements.
  """
  @spec linkify_html(String.t()) :: String.t()
  def linkify_html(html) when is_binary(html) do
    {parts, _protected_stack} =
      ~r/(<[^>]+>)/
      |> Regex.split(html, include_captures: true)
      |> Enum.reduce({[], []}, &linkify_html_segment/2)

    parts
    |> Enum.reverse()
    |> Enum.join()
  end

  @protected_html_tags ~w(a code pre)

  # --- URL Extraction ---

  @spec find_urls(String.t()) :: [String.t()]
  defp find_urls(text) do
    @url_pattern
    |> Regex.scan(text)
    |> List.flatten()
    |> Enum.map(&trim_url/1)
  end

  @spec trim_url(String.t()) :: String.t()
  defp trim_url(url) do
    url
    |> trim_trailing_punct()
    |> trim_unbalanced_parens()
    |> trim_unbalanced_brackets()
    |> trim_trailing_punct()
  end

  @spec trim_trailing_punct(String.t()) :: String.t()
  defp trim_trailing_punct(url) do
    case String.last(url) do
      nil ->
        url

      last_char ->
        if :binary.first(last_char) in @trailing_punct do
          url |> String.slice(0..-2//1) |> trim_trailing_punct()
        else
          url
        end
    end
  end

  @spec trim_unbalanced_parens(String.t()) :: String.t()
  defp trim_unbalanced_parens(url) do
    trim_unbalanced(url, "(", ")")
  end

  @spec trim_unbalanced_brackets(String.t()) :: String.t()
  defp trim_unbalanced_brackets(url) do
    trim_unbalanced(url, "[", "]")
  end

  @spec trim_unbalanced(String.t(), String.t(), String.t()) :: String.t()
  defp trim_unbalanced(url, open, close) do
    open_count = count_char(url, open)
    close_count = count_char(url, close)

    if close_count > open_count and String.ends_with?(url, close) do
      url
      |> String.slice(0..-2//1)
      |> trim_unbalanced(open, close)
    else
      url
    end
  end

  @spec count_char(String.t(), String.t()) :: non_neg_integer()
  defp count_char(str, char) do
    str |> String.graphemes() |> Enum.count(&(&1 == char))
  end

  # --- Linkification ---

  @spec linkify_text(String.t(), (String.t() -> String.t())) :: String.t()
  defp linkify_text("", _escape_fn), do: ""

  defp linkify_text(text, escape_fn) do
    # Extract raw text content (stripping HTML tags) for URL detection
    plain = strip_html_tags(text)
    urls = find_urls(plain)

    if urls == [] do
      escape_fn.(text)
    else
      replace_urls_in_text(text, urls, escape_fn)
    end
  end

  @spec replace_urls_in_text(String.t(), [String.t()], (String.t() -> String.t())) :: String.t()
  defp replace_urls_in_text(text, urls, escape_fn) do
    # Build a regex that matches any of the URLs (longest first to avoid partial matches)
    sorted_urls = Enum.sort_by(urls, &String.length/1, :desc)

    escaped_urls =
      Enum.map(sorted_urls, fn url -> Regex.escape(url) end)

    pattern = Regex.compile!(Enum.join(escaped_urls, "|"))

    parts = Regex.split(pattern, text, include_captures: true)

    parts
    |> Enum.map(fn part ->
      if part in urls do
        build_link(part)
      else
        escape_fn.(part)
      end
    end)
    |> Enum.join()
  end

  defp linkify_html_segment("<" <> _ = tag, {acc, protected_stack}) do
    protected_stack = update_protected_stack(tag, protected_stack)
    {[tag | acc], protected_stack}
  end

  defp linkify_html_segment(text, {acc, []}) do
    {[linkify_text(text, &Function.identity/1) | acc], []}
  end

  defp linkify_html_segment(text, {acc, protected_stack}), do: {[text | acc], protected_stack}

  defp update_protected_stack(tag, protected_stack) do
    cond do
      closing_protected_tag?(tag) ->
        remove_first(protected_stack, tag_name(tag))

      opening_protected_tag?(tag) ->
        [tag_name(tag) | protected_stack]

      true ->
        protected_stack
    end
  end

  defp opening_protected_tag?(tag) do
    name = tag_name(tag)

    name in @protected_html_tags and
      !String.starts_with?(tag, "</") and
      !String.ends_with?(String.trim(tag), "/>")
  end

  defp closing_protected_tag?(tag),
    do: String.starts_with?(tag, "</") and tag_name(tag) in @protected_html_tags

  defp tag_name(tag) do
    case Regex.run(~r/^<\/?\s*([a-zA-Z0-9:-]+)/, tag) do
      [_match, name] -> String.downcase(name)
      nil -> ""
    end
  end

  defp remove_first([], _tag_name), do: []
  defp remove_first([tag_name | rest], tag_name), do: rest
  defp remove_first([other | rest], tag_name), do: [other | remove_first(rest, tag_name)]

  @spec strip_html_tags(String.t()) :: String.t()
  defp strip_html_tags(html) do
    Regex.replace(~r/<[^>]*>/, html, "")
  end

  @spec build_link(String.t()) :: String.t()
  defp build_link(url) do
    display = truncate_display(url)
    escaped_href = html_escape_attr(url)

    ~s(<a href="#{escaped_href}" target="_blank" rel="noopener noreferrer" class="chat-link" title="#{escaped_href}" data-url="#{escaped_href}">#{display}</a>)
  end

  @spec truncate_display(String.t()) :: String.t()
  defp truncate_display(url) when byte_size(url) > 0 do
    if String.length(url) > @max_display_length do
      url |> String.slice(0, @max_display_length) |> html_escape() |> Kernel.<>("...")
    else
      html_escape(url)
    end
  end

  @spec html_escape(String.t()) :: String.t()
  defp html_escape(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  @spec html_escape_attr(String.t()) :: String.t()
  defp html_escape_attr(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
