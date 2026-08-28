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

  # Exact, never a prefix match: `https://retrohexchat.app.evil.example` starts
  # with our name and is not us, and neither is `https://retrohex`.
  defp ours?(""), do: true
  defp ours?(prefix), do: prefix == SEO.origin()
end
