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
    %{id: "doom", name: "DOOM", description: "Episode 1", engine: gettext("DOOM Engine")},
    %{
      id: "freedoom1",
      name: "Freedoom Phase 1",
      description: gettext("36 levels"),
      engine: gettext("DOOM Engine")
    },
    %{
      id: "quake",
      name: "LibreQuake",
      description: gettext("Open-source Quake"),
      engine: gettext("Quake Engine")
    },
    %{
      id: "wolfenstein",
      name: "Wolfenstein 3D",
      description: gettext("Shareware Classic"),
      engine: gettext("Wolf3D Engine")
    },
    %{
      id: "bass",
      name: "Beneath a Steel Sky",
      description: gettext("Point & Click"),
      engine: gettext("ScummVM")
    },
    %{
      id: "chex",
      name: "Chex Quest",
      description: gettext("Cereal box classic"),
      engine: gettext("DOOM Engine")
    }
  ]

  @sample_preview %{
    id: "doom",
    name: "DOOM",
    description: gettext("Episode 1 — The Original"),
    engine: gettext("DOOM Engine (PrBoom+)"),
    about: [
      gettext("The original first-person shooter that defined the genre."),
      gettext("Fight through hordes of demons from Hell in this classic 1993 game.")
    ],
    controls: [
      {gettext("WASD"), gettext("Move")},
      {gettext("Mouse"), gettext("Look / Aim")},
      {gettext("Left Click"), gettext("Shoot")},
      {"E", gettext("Use / Open doors")},
      {"1-7", gettext("Switch weapons")}
    ],
    tips: [
      gettext("Look for secret walls by pressing Use against suspicious textures"),
      gettext("Save often - ammo and health can be scarce"),
      gettext("The chainsaw is surprisingly effective against Pinkies")
    ]
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Solo Lobby"),
       active_page: "solo-lobby",
       sample_games: @sample_games,
       sample_preview: @sample_preview
     )}
  end
end
