defmodule RetroHexChatWeb.Site.Pages.Games do
  @moduledoc """
  The public games catalogue: every game, as a picture and a line, each one a
  link to its own page.
  """
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.UI.Landing.GameCards

  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    {:ok,
     %{
       active_page: :games,
       windows: [
         Window.intro(dgettext("landing", "Retro games in your browser"), :icon_joystick,
           taskbar_label: dgettext("landing", "Games"),
           heading_id: "games-heading",
           description:
             dgettext(
               "landing",
               "Shareware classics and freeware adventures running on their original engines, and arcade games to play against a friend or the AI. Free, and nothing to install: pick a nickname and play."
             )
         ),
         cards_window("arcade", dgettext("landing", "Arcade"), :icon_game_arcade, :arcade),
         cards_window(
           "multiplayer",
           dgettext("landing", "Retro Games"),
           :icon_joystick,
           :multiplayer
         )
       ],
       canonical_path: "/games",
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), PublicPages.localized_path("/")},
           {dgettext("landing", "Games"), PublicPages.localized_path("/games")}
         ])
       ],
       page_title:
         dgettext("landing", "Retro games you can play in your browser — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "DOOM, Quake, Wolfenstein 3D, Half-Life and classic adventures in the browser, plus multiplayer arcade games to play with friends — free, nothing to install."
         )
     }}
  end

  # Both catalogues on their category shelves, the same ones the app's
  # folders show.
  defp cards_window(id, title, icon, kind) do
    groups = GameCatalog.cards(kind)
    every_card = Enum.flat_map(groups, & &1.cards)

    Window.new(id, title, icon,
      width: 1000,
      body: &game_card_list/1,
      assigns: %{
        heading_id: id <> "-heading",
        groups: groups,
        columns: "grid-cols-2 md:grid-cols-3 lg:grid-cols-4",
        catalogue_path: nil
      },
      status: [dngettext("landing", "%{count} game", "%{count} games", length(every_card))]
    )
  end
end
