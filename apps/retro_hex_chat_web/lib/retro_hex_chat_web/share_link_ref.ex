defmodule RetroHexChatWeb.ShareLinkRef do
  @moduledoc """
  What a share URL looks like, in both directions.

  Building one and recognising one were about to be written in two places —
  the surface that mints a link and the conversation that draws a card for it.
  Two spellings of the same shape is how a link the app produced stops being a
  link the app recognises, so both live here.

  Recognition is deliberately narrow. A path with no host is ours because a
  person typed it into this chat; an absolute URL is ours only when the host is.
  Otherwise a message linking to somebody else's `/join/` page would draw a card
  claiming it leads here.

  Locale segments count, because every public page in this app also lives under
  one and a link copied from a pt-BR browser is the same link. Only the segments
  the router registers are accepted, read from the same list the router builds
  its scopes from.
  """

  alias RetroHexChat.ShareLinks.Slug
  alias RetroHexChatWeb.SEO

  @locale_alternation SEO.localized_locale_segments()
                      |> Enum.map(&Regex.escape/1)
                      |> Enum.join("|")

  @pattern Regex.compile!(
             "(?<prefix>https?://[^\\s/]+)?" <>
               "(?:/(?:#{@locale_alternation}))?" <>
               "/join/(?<slug>[a-z2-9]{#{Slug.length()}})(?![a-z2-9])"
           )

  # A P2P invite carries the session's own address rather than a minted slug:
  # the token *is* the invitation, there is nothing to revoke separately, and
  # a link nobody but the two of them can use has no business in a database of
  # shareable addresses. It still draws the same card, which is what the plan
  # asked for — a variant, not a second component.
  @p2p_pattern Regex.compile!("(?<prefix>https?://[^\\s/]+)?/p2p/(?<token>[A-Za-z0-9_-]{8,})")

  @doc "The absolute URL a slug is shared as."
  @spec url(String.t()) :: String.t()
  def url(slug), do: SEO.site_url("/join/" <> slug)

  @doc """
  Every slug this text points at, in the order they appear, without repeats.
  """
  @spec slugs_in(term()) :: [String.t()]
  def slugs_in(text) when is_binary(text) do
    @pattern
    |> Regex.scan(text, capture: :all_names)
    |> Enum.filter(fn [prefix, _slug] -> ours?(prefix) end)
    |> Enum.map(fn [_prefix, slug] -> slug end)
    |> Enum.uniq()
  end

  def slugs_in(_text), do: []

  @doc """
  The P2P session an invite line points at, or `nil`.

  One, not a list: an invite is one session, and a message that mentioned two
  would be somebody quoting rather than being invited.
  """
  @spec p2p_token_in(term()) :: String.t() | nil
  def p2p_token_in(text) when is_binary(text) do
    case Regex.named_captures(@p2p_pattern, text) do
      %{"prefix" => prefix, "token" => token} -> if ours?(prefix), do: token
      nil -> nil
    end
  end

  def p2p_token_in(_text), do: nil

  # Exact, never a prefix match: `https://retrohexchat.app.evil.example` starts
  # with our name and is not us, and neither is `https://retrohex`.
  defp ours?(""), do: true
  defp ours?(prefix), do: prefix == SEO.origin()
end
