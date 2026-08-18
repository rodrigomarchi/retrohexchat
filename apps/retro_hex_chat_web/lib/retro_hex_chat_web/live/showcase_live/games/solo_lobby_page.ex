defmodule RetroHexChatWeb.ShowcaseLive.Games.SoloLobbyPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.SoloLobby
  import RetroHexChatWeb.ShowcaseHelpers

  @sample_games [
    %{
      id: "doom_shareware",
      name: "DOOM",
      description: dgettext("showcase", "Episode 1"),
      engine: dgettext("showcase", "DOOM Engine")
    },
    %{
      id: "freedoom1",
      name: "Freedoom Phase 1",
      description: dgettext("showcase", "36 levels"),
      engine: dgettext("showcase", "DOOM Engine")
    },
    %{
      id: "librequake",
      name: "LibreQuake",
      description: dgettext("showcase", "Open-source Quake"),
      engine: dgettext("showcase", "Quake Engine")
    },
    %{
      id: "wolfenstein_3d",
      name: "Wolfenstein 3D",
      description: dgettext("showcase", "Shareware Classic"),
      engine: dgettext("showcase", "Wolf3D Engine")
    },
    %{
      id: "scummvm_bass",
      name: "Beneath a Steel Sky",
      description: dgettext("showcase", "Point & Click"),
      engine: dgettext("showcase", "ScummVM")
    },
    %{
      id: "chex_quest",
      name: "Chex Quest",
      description: dgettext("showcase", "Cereal box classic"),
      engine: dgettext("showcase", "DOOM Engine")
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Solo Lobby"),
       active_page: "solo-lobby",
       sample_games: @sample_games
     )}
  end
end
