defmodule RetroHexChat.Chat.Highlight do
  @moduledoc """
  Pure-function highlight matching engine.

  Checks message content against a user's own nickname and custom
  highlight words. Returns `{:highlight, color_index}` or `:no_highlight`.

  All matching is whole-word, case-insensitive, and ignores:
  - IRC formatting codes (stripped before matching)
  - Text inside URLs (masked before matching)
  """

  alias RetroHexChat.Chat.Formatter
  alias RetroHexChat.Chat.HighlightWord

  @url_pattern ~r{https?://\S+}i

  @doc """
  Checks if `content` contains the user's own nick or any custom highlight words.

  Returns `{:highlight, color_index}` with the winning color index, or `:no_highlight`.
  A `nil` color index means "use the default highlight color" (CSS class `highlight-bg-default`).
  A numeric index (0–15) maps to an IRC color (CSS class `irc-bg-N`).

  ## Priority

  1. Own nick match → default highlight color (`nil`)
  2. Custom words in list order → word's custom color index or default (`nil`)

  ## Exclusions

  - Self-highlight: if `sender_nick == own_nick`, always returns `:no_highlight`
  - URLs: words inside `http://` or `https://` URLs are not matched
  - Formatting: IRC format codes are stripped before matching
  """
  @spec check(String.t(), String.t(), [HighlightWord.t()], String.t()) ::
          {:highlight, non_neg_integer() | nil} | :no_highlight
  def check("", _own_nick, _highlight_words, _sender_nick), do: :no_highlight

  def check(content, own_nick, highlight_words, sender_nick) do
    if String.downcase(sender_nick) == String.downcase(own_nick) do
      :no_highlight
    else
      plain = content |> Formatter.strip() |> mask_urls()
      check_words(plain, own_nick, highlight_words)
    end
  end

  @spec check_words(String.t(), String.t(), [HighlightWord.t()]) ::
          {:highlight, non_neg_integer() | nil} | :no_highlight
  defp check_words(plain, own_nick, highlight_words) do
    if whole_word_match?(plain, own_nick) do
      {:highlight, nil}
    else
      check_custom_words(plain, highlight_words)
    end
  end

  @spec check_custom_words(String.t(), [HighlightWord.t()]) ::
          {:highlight, non_neg_integer() | nil} | :no_highlight
  defp check_custom_words(_plain, []), do: :no_highlight

  defp check_custom_words(plain, [word | rest]) do
    if whole_word_match?(plain, word.word) do
      {:highlight, word.bg_color}
    else
      check_custom_words(plain, rest)
    end
  end

  @spec whole_word_match?(String.t(), String.t()) :: boolean()
  defp whole_word_match?(_text, ""), do: false

  defp whole_word_match?(text, word) do
    escaped = Regex.escape(word)
    # Use lookaround assertions instead of \b so that words containing
    # non-word characters (e.g., "C++", "Nick[away]") are matched correctly.
    pattern = Regex.compile!("(?<![\\w])#{escaped}(?![\\w])", "i")
    Regex.match?(pattern, text)
  end

  @spec mask_urls(String.t()) :: String.t()
  defp mask_urls(text) do
    Regex.replace(@url_pattern, text, fn match ->
      String.duplicate(" ", String.length(match))
    end)
  end
end
