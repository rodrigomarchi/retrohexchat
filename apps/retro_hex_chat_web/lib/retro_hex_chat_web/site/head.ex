defmodule RetroHexChatWeb.Site.Head do
  @moduledoc """
  What the `<head>` of the one desktop says about the address it is at.

  A page of the site names its own title, description, canonical address and
  structured data under fixed keys (`page_title`, `page_description`,
  `canonical_path`, …); `from_page/1` reads them, with the site's defaults for
  any a page leaves out. The chat's
  own addresses — a channel, a member's home — get `for_chat/2`: a title, and
  `noindex`, because a live conversation is not something to put in an index.
  """

  alias RetroHexChatWeb.SEO

  @default_title "Retro Hex Chat — Self-hosted chat with P2P calls"
  @default_description "Run your own chat server. Your data stays with you. Voice and video calls go directly between users via P2P. Open source, self-hosted, and free as in freedom."

  @type t :: %{
          title: String.t(),
          description: String.t(),
          canonical_path: String.t(),
          canonical_url: String.t(),
          hreflang?: boolean(),
          robots: String.t(),
          og_image: map(),
          og_type: String.t(),
          json_ld: [String.t()]
        }

  @doc "The head a page describes itself with, from the map it loaded."
  @spec from_page(map()) :: t()
  def from_page(page) do
    canonical_path = page[:canonical_path] || "/"
    description = page[:page_description] || @default_description

    %{
      title: page[:page_title] || @default_title,
      description: description,
      canonical_path: canonical_path,
      canonical_url: page[:canonical_url] || SEO.canonical_url(canonical_path),
      hreflang?: page[:hreflang_alternates] != false,
      robots: page[:robots] || "index, follow",
      og_image: page[:og_image] || SEO.social_image(),
      og_type: page[:og_type] || "website",
      json_ld: page[:json_ld] || [SEO.software_application_json_ld(description)]
    }
  end

  @doc """
  The head of one of the chat's own addresses: its title, never indexed.
  `canonical_path` is the address itself, unprefixed.
  """
  @spec for_chat(String.t(), String.t()) :: t()
  def for_chat(title, canonical_path) do
    %{
      from_page(%{page_title: title, canonical_path: canonical_path, json_ld: []})
      | hreflang?: false,
        robots: SEO.noindex_content()
    }
  end
end
