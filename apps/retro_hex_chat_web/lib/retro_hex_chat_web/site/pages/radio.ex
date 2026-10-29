# ex_dna:disable-for-next-line a page's declaration: its own words, built by Pages.Accessory
defmodule RetroHexChatWeb.Site.Pages.Radio do
  @moduledoc """
  The public page of Hex Radio, the internet radio player of the desktop:
  the page a search for "online radio" or "internet radio player" should land
  on. Built by `Site.Pages.Accessory`; this says only what is Hex Radio's.
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
        key: "radio",
        feature: :radio,
        window: "radio",
        path: "/radio",
        name: "Hex Radio",
        icon: :icon_radio,
        description:
          dgettext(
            "landing",
            "Listen to internet radio for free in a retro player: thousands of stations from around the world, a spectrum and an equalizer."
          ),
        title:
          dgettext("landing", "Hex Radio: listen to internet radio online in a retro player"),
        alt:
          dgettext("landing", "Hex Radio playing a chiptune station, its spectrum lit in green"),
        help: ~w(ui-hex-radio cmd-radio keyboard-shortcuts),
        intro: &intro/1,
        panes: [
          {"sound", dgettext("landing", "Spectrum and equalizer"), :icon_equalizer, &sound/1}
        ],
        how: &how/1
      },
      ctx
    )
  end

  embed_templates "radio/*"
end
