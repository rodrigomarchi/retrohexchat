defmodule RetroHexChatWeb.Site.Pages.Games do
  @moduledoc """
  The public games catalogue: every game, as a picture and a line, each one a
  link to its own page.
  """
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.UI.Landing.GameCards

  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    arcade = cards(:arcade)
    multiplayer = cards(:multiplayer)

    {:ok,
     %{
       active_page: :games,
       arcade: arcade,
       multiplayer: multiplayer,
       windows: [
         %{id: "intro", label: dgettext("landing", "Games"), icon: :icon_joystick},
         %{id: "arcade", label: dgettext("landing", "Solo Arcade"), icon: :icon_joystick},
         %{
           id: "multiplayer",
           label: dgettext("landing", "Multiplayer Games"),
           icon: :icon_joystick
         }
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

  defp cards(kind) do
    kind
    |> GameCatalog.list()
    |> Enum.map(&%{game: &1, path: PublicPages.localized_path(GameCatalog.page_path(&1))})
  end

  embed_templates "games.html"

  @impl RetroHexChatWeb.Site.Page
  def render(assigns), do: games(assigns)
end
