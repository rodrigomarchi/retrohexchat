# ex_dna:disable-for-next-line a page's declaration: its own words, built by Pages.Accessory
defmodule RetroHexChatWeb.Site.Pages.AsciiArt do
  @moduledoc """
  The public page of ASCII Art, the text art maker of the desktop: the page
  a search for "ASCII art generator" or "text banner" should land on. Built by
  `Site.Pages.Accessory`; this says only what is ASCII Art's.
  """
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.UI.Button

  # ex_dna:disable-for-next-line a page's declaration: its own words, built by Pages.Accessory
  import RetroHexChatWeb.Components.UI.Inset

  # ex_dna:disable-for-next-line a page's declaration: its own words, built by Pages.Accessory
  import RetroHexChatWeb.Components.UI.Landing.Screenshot

  # ex_dna:disable-for-next-line a page's declaration: its own words, built by Pages.Accessory
  alias RetroHexChatWeb.Icons

  # ex_dna:disable-for-next-line a page's declaration: its own words, built by Pages.Accessory
  alias RetroHexChatWeb.Site.Pages.Accessory

  @impl RetroHexChatWeb.Site.Page
  def load(_params, ctx) do
    Accessory.load(
      %{
        key: "ascii_art",
        feature: :ascii_art,
        window: "ascii-art",
        path: "/ascii-art",
        name: dgettext("landing", "ASCII Art"),
        icon: :icon_ascii_art,
        description:
          dgettext(
            "landing",
            "Make ASCII art in mIRC colours for free: text banners, pictures and pixel drawings, posted to a chat room as one message."
          ),
        title: dgettext("landing", "Free ASCII art generator: text banners in mIRC colours"),
        alt: dgettext("landing", "The word RETRO as a rainbow banner made of text characters"),
        help: ~w(ui-ascii-art cmd-ascii ui-hex-paint formatting-colors),
        intro: &intro/1,
        chat: &chat/1,
        how: &how/1
      },
      ctx
    )
  end

  embed_templates "ascii_art/*"
end
