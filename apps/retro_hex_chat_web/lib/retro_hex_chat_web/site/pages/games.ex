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
    arcade = cards(:arcade)
    multiplayer = cards(:multiplayer)

    {:ok,
     %{
       active_page: :games,
       windows: [
         Window.new("intro", dgettext("landing", "Retro games in your browser"), :icon_joystick,
           width: 640,
           taskbar_label: dgettext("landing", "Games"),
           body: &page_intro/1,
           assigns: %{
             heading_id: "games-heading",
             description:
               dgettext(
                 "landing",
                 "Shareware classics and freeware adventures running on their original engines, and arcade games to play against a friend or the AI. Free, and nothing to install: pick a nickname and play."
               )
           }
         ),
         cards_window("arcade", dgettext("landing", "Solo Arcade"), :icon_game_arcade, arcade),
         cards_window(
           "multiplayer",
           dgettext("landing", "Multiplayer Games"),
           :icon_joystick,
           multiplayer
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

  defp cards_window(id, title, icon, cards) do
    Window.new(id, title, icon,
      width: 1000,
      body: &game_card_list/1,
      assigns: %{
        heading_id: id <> "-heading",
        cards: cards,
        columns: "grid-cols-2 md:grid-cols-3 lg:grid-cols-4",
        catalogue_path: nil
      },
      status: [dngettext("landing", "%{count} game", "%{count} games", length(cards))]
    )
  end

  defp cards(kind) do
    kind
    |> GameCatalog.list()
    |> Enum.map(&%{game: &1, path: PublicPages.localized_path(GameCatalog.page_path(&1))})
  end
end
