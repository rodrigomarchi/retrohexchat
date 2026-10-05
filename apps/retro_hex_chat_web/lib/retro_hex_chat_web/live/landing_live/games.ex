defmodule RetroHexChatWeb.LandingLive.Games do
  @moduledoc """
  The public games catalogue: every game, as a picture and a line, each one a
  link to its own page.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Landing.GameCards

  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    arcade = cards(:arcade)
    multiplayer = cards(:multiplayer)

    {:ok,
     assign(socket,
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
     )}
  end

  defp cards(kind) do
    kind
    |> GameCatalog.list()
    |> Enum.map(&%{game: &1, path: PublicPages.localized_path(GameCatalog.page_path(&1))})
  end
end
