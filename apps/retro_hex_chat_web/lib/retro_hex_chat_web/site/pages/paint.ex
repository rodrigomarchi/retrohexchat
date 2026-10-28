# ex_dna:disable-for-next-line a page's declaration: its own words, built by Pages.Accessory
defmodule RetroHexChatWeb.Site.Pages.Paint do
  @moduledoc """
  The public page of Hex Paint, the pixel drawing program of the desktop:
  the page a search for "pixel art online" or "paint online" should land on.
  Built by `Site.Pages.Accessory`; this says only what is Hex Paint's.
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
        key: "paint",
        feature: :paint,
        window: "paint",
        path: "/paint",
        name: "Hex Paint",
        icon: :icon_paint,
        description:
          dgettext(
            "landing",
            "Draw pixel art in sixteen retro colours in your browser, then post your drawing to a chat room. Free, with a Windows 98 look."
          ),
        title: dgettext("landing", "Hex Paint: draw pixel art online and share it in a chat"),
        alt: dgettext("landing", "Hex Paint open on a pixel-art heart over a starry night"),
        help: ~w(ui-hex-paint cmd-paint ui-ascii-art keyboard-shortcuts),
        intro: &intro/1,
        chat: &chat/1,
        how: &how/1
      },
      ctx
    )
  end

  embed_templates "paint/*"
end
