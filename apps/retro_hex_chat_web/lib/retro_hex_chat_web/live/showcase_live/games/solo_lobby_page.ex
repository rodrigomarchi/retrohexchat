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

  @sample_preview %{
    id: "doom_shareware",
    name: "DOOM",
    description: dgettext("showcase", "Episode 1 — The Original"),
    engine: dgettext("showcase", "DOOM Engine (PrBoom+)"),
    about: [
      dgettext(
        "showcase",
        "The original first-person shooter that defined the genre."
      ),
      dgettext(
        "showcase",
        "Fight through hordes of demons from Hell in this classic 1993 game."
      )
    ],
    controls: [
      {"WASD", dgettext("showcase", "Move")},
      {"Mouse", dgettext("showcase", "Look / Aim")},
      {"Left Click", dgettext("showcase", "Fire")},
      {"E", dgettext("showcase", "Use / Open doors")},
      {"1-7", dgettext("showcase", "Switch weapons")}
    ],
    tips: [
      dgettext("showcase", "Look for secret walls by pressing Use against suspicious textures"),
      dgettext("showcase", "Save often - ammo and health can be scarce"),
      dgettext("showcase", "The chainsaw is surprisingly effective against Pinkies")
    ]
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Solo Lobby"),
       active_page: "solo-lobby",
       sample_games: @sample_games,
       sample_preview: @sample_preview
     )}
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}
end
