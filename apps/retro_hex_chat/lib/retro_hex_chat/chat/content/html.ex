defmodule RetroHexChat.Chat.Content.Html do
  @moduledoc """
  Rewriting the text of already-rendered HTML without touching its markup.

  Two things decorate a rendered message after the fact — a URL becomes a link,
  a `#channel` becomes something clickable — and both have the same problem: the
  text they are looking for also appears inside tags they must leave alone. A
  URL inside an `<a href>` is already a link, and anything inside `<code>` or
  `<pre>` is being quoted rather than written.

  So both walk the fragment tag by tag, keeping a stack of the protected tags
  they are currently inside, and rewrite only the text found outside all of
  them. That walk was written twice, once in the domain and once in the web
  layer, down to the same list of protected tags; only the rewriting differed.
  """

  # Inside these, text is already a link or is being quoted. Either way it is
  # not ours to change.
  @protected_tags ~w(a code pre)

  @doc """
  Applies `rewrite` to every run of text outside a protected tag.

  Tags themselves are passed through untouched, so the fragment's markup is the
  same on the way out.
  """
  @spec rewrite_text(String.t(), (String.t() -> String.t())) :: String.t()
  def rewrite_text(html, rewrite) when is_binary(html) and is_function(rewrite, 1) do
    {parts, _protected} =
      ~r/(<[^>]+>)/
      |> Regex.split(html, include_captures: true)
      |> Enum.reduce({[], []}, &segment(&1, &2, rewrite))

    parts
    |> Enum.reverse()
    |> Enum.join()
  end

  defp segment("<" <> _ = tag, {acc, protected}, _rewrite),
    do: {[tag | acc], protected_after(tag, protected)}

  defp segment(text, {acc, []}, rewrite), do: {[rewrite.(text) | acc], []}
  defp segment(text, {acc, protected}, _rewrite), do: {[text | acc], protected}

  defp protected_after(tag, protected) do
    cond do
      closing_protected?(tag) -> remove_first(protected, tag_name(tag))
      opening_protected?(tag) -> [tag_name(tag) | protected]
      true -> protected
    end
  end

  defp opening_protected?(tag) do
    tag_name(tag) in @protected_tags and
      not String.starts_with?(tag, "</") and
      not String.ends_with?(String.trim(tag), "/>")
  end

  defp closing_protected?(tag),
    do: String.starts_with?(tag, "</") and tag_name(tag) in @protected_tags

  defp tag_name(tag) do
    case Regex.run(~r/^<\/?\s*([a-zA-Z0-9:-]+)/, tag) do
      [_match, name] -> String.downcase(name)
      nil -> ""
    end
  end

  # Closes the nearest matching tag rather than every one of them: nested
  # `<code>` inside `<a>` has to leave the outer one open.
  defp remove_first([], _tag_name), do: []
  defp remove_first([tag_name | rest], tag_name), do: rest
  defp remove_first([other | rest], tag_name), do: [other | remove_first(rest, tag_name)]
end
