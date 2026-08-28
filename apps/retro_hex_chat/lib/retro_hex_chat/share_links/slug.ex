defmodule RetroHexChat.ShareLinks.Slug do
  @moduledoc """
  The opaque name a share link is known by, and the two numbers behind it.

  A slug is read off a screen, typed on a phone, pasted into a channel and
  posted to a social network. So the alphabet leaves out the characters that get
  confused doing that — `0`/`o`, `1`/`l`/`i` — leaving 23 letters and 8 digits.
  Everything left is URL-safe as it stands, with nothing to escape.

  Length is a security parameter, not a style choice. A slug is the only thing
  between a stranger and the knowledge that a room exists, so guessing one has
  to be impractical: 31^10 is about 8.2 x 10^14, which at a thousand guesses a
  second against a rate-limited public route is not a strategy. Shortening it is
  a decision about that number, which is why the number itself is asserted in
  the tests.

  It is deliberately not a signed token. A token expires and a share link is
  meant to outlive the room it names — the card it resolves to has to be useful
  after the call ended, which is most of the time a shared link is alive.
  """

  @alphabet ~c"abcdefghjkmnpqrstuvwxyz23456789"
  @alphabet_size length(@alphabet)
  @length 10

  # Derived, never written twice. Hand-writing the character class is how
  # `valid?/1` came to accept `i`, `l` and `o` — the three letters `generate/0`
  # exists to keep out.
  @pattern Regex.compile!("\\A[#{@alphabet}]{#{@length}}\\z")

  @doc "A new slug, uniform over the alphabet."
  @spec generate() :: String.t()
  def generate do
    1..@length
    |> Enum.map(fn _ -> Enum.random(@alphabet) end)
    |> List.to_string()
  end

  @doc """
  Whether `value` could have come from `generate/0`.

  Accepts exactly what `generate/0` produces, and is checked before any lookup
  so a malformed slug costs a regex and not a query. Strict on purpose: a
  character the generator refuses to emit is one the system never has to store,
  compare or display.
  """
  @spec valid?(term()) :: boolean()
  def valid?(value) when is_binary(value), do: Regex.match?(@pattern, value)
  def valid?(_value), do: false

  @doc "How many characters the alphabet has."
  @spec alphabet_size() :: pos_integer()
  def alphabet_size, do: @alphabet_size

  @doc "How many characters a slug has."
  @spec length() :: pos_integer()
  def length, do: @length
end
