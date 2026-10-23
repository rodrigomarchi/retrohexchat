defmodule RetroHexChat.Text do
  @moduledoc """
  Small text operations shared by the domain and the web layer.

  `truncate/3` is the one way text is shortened for display: link cards, feed
  excerpts, reply quotes, previews. The result, omission included, never
  exceeds the limit, so a card or a quote never outgrows the room left for it.
  """

  @default_omission "..."

  @doc """
  Shortens `text` to at most `max` graphemes, omission included.

  Text that already fits is returned unchanged. `omission:` sets the marker
  (default `"..."`). `nil` stays `nil`.

      iex> RetroHexChat.Text.truncate("Nintendo anuncia novo console", 12)
      "Nintendo ..."
      iex> RetroHexChat.Text.truncate("short", 12)
      "short"
  """
  @spec truncate(String.t() | nil, integer(), keyword()) :: String.t() | nil
  def truncate(text, max, opts \\ [])
  def truncate(nil, _max, _opts), do: nil
  def truncate(_text, max, _opts) when max <= 0, do: ""

  def truncate(text, max, opts) when is_binary(text) do
    omission = Keyword.get(opts, :omission, @default_omission)

    cond do
      String.length(text) <= max -> text
      String.length(omission) >= max -> String.slice(text, 0, max)
      true -> String.slice(text, 0, max - String.length(omission)) <> omission
    end
  end

  @doc """
  `nil` for `nil` or a string that is empty or only whitespace; anything else
  is returned unchanged.
  """
  @spec blank_to_nil(term()) :: term()
  def blank_to_nil(nil), do: nil

  def blank_to_nil(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  def blank_to_nil(value), do: value

  @doc "Whitespace-separated words in `text`; `nil` for `nil` or empty text."
  @spec word_count(String.t() | nil) :: non_neg_integer() | nil
  def word_count(text) when is_binary(text) and text != "", do: text |> String.split() |> length()
  def word_count(_text), do: nil

  @doc "A string with something in it besides whitespace."
  @spec present?(term()) :: boolean()
  def present?(value) when is_binary(value), do: String.trim(value) != ""
  def present?(_value), do: false

  @doc "`nil`, or a string that is empty or only whitespace: the opposite of `present?/1`."
  @spec blank?(term()) :: boolean()
  def blank?(value), do: not present?(value)
end
