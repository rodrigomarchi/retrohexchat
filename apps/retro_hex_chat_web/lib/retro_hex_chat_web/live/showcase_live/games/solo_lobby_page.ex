defmodule RetroHexChatWeb.ShowcaseLive.Games.SoloLobbyPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.SoloLobby
  import RetroHexChatWeb.ShowcaseHelpers

  @sample_games [
    %{id: "doom", name: "DOOM", description: "Episode 1", engine: "DOOM Engine"},
    %{id: "freedoom1", name: "Freedoom Phase 1", description: "36 levels", engine: "DOOM Engine"},
    %{id: "quake", name: "LibreQuake", description: "Open-source Quake", engine: "Quake Engine"},
    %{
      id: "wolfenstein",
      name: "Wolfenstein 3D",
      description: "Shareware Classic",
      engine: "Wolf3D Engine"
    },
    %{id: "bass", name: "Beneath a Steel Sky", description: "Point & Click", engine: "ScummVM"},
    %{id: "chex", name: "Chex Quest", description: "Cereal box classic", engine: "DOOM Engine"}
  ]

  @sample_preview %{
    id: "doom",
    name: "DOOM",
    description: "Episode 1 — The Original",
    engine: "DOOM Engine (PrBoom+)",
    about: [
      "The original first-person shooter that defined the genre.",
      "Fight through hordes of demons from Hell in this classic 1993 game."
    ],
    controls: [
      {"WASD", "Move"},
      {"Mouse", "Look / Aim"},
      {"Left Click", "Shoot"},
      {"E", "Use / Open doors"},
      {"1-7", "Switch weapons"}
    ],
    tips: [
      "Look for secret walls by pressing Use against suspicious textures",
      "Save often - ammo and health can be scarce",
      "The chainsaw is surprisingly effective against Pinkies"
    ]
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Solo Lobby",
       active_page: "solo-lobby",
       sample_games: @sample_games,
       sample_preview: @sample_preview
     )}
  end
end
