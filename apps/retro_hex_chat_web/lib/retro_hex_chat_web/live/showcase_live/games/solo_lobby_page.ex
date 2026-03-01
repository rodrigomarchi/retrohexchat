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

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Solo Lobby</h2>

      <.showcase_card
        title="Lobby — Game Picker"
        description="Initial state showing the game selection grid."
      >
        <div class="max-w-lg">
          <.solo_lobby
            id="lobby-picker"
            nickname="Troll"
            games={@sample_games}
            session_status="lobby"
          />
        </div>
        <.code_example>
          &lt;.solo_lobby
          id="lobby-picker"
          nickname="Troll"
          games=&#123;@games&#125;
          session_status="lobby"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Lobby — Game Preview"
        description="Detail view after clicking a game card, showing about, controls, and tips."
      >
        <div class="max-w-lg">
          <.solo_lobby
            id="lobby-preview"
            nickname="Troll"
            games={@sample_games}
            session_status="lobby"
            previewed_game={@sample_preview}
          />
        </div>
        <.code_example>
          &lt;.solo_lobby
          id="lobby-preview"
          nickname="Troll"
          games=&#123;@games&#125;
          session_status="lobby"
          previewed_game=&#123;@previewed_game&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Playing State"
        description="Active game session with timer and end session button."
      >
        <div class="max-w-lg">
          <.solo_lobby
            id="lobby-playing"
            nickname="Troll"
            games={@sample_games}
            session_status="playing"
            game_name="DOOM"
            game_id="doom"
            game_started_at="2026-02-27T14:30:00Z"
          />
        </div>
        <.code_example>
          &lt;.solo_lobby
          id="lobby-playing"
          nickname="Troll"
          games=&#123;@games&#125;
          session_status="playing"
          game_name="DOOM"
          game_id="doom"
          game_started_at="2026-02-27T14:30:00Z"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Finished State"
        description="Session complete with play time summary."
      >
        <div class="max-w-lg">
          <.solo_lobby
            id="lobby-finished"
            nickname="Troll"
            games={@sample_games}
            session_status="finished"
            game_name="DOOM"
            game_id="doom"
            game_duration={1847}
          />
        </div>
        <.code_example>
          &lt;.solo_lobby
          id="lobby-finished"
          session_status="finished"
          game_name="DOOM"
          game_duration=&#123;1847&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Inactivity Warning"
        description="Warning overlay shown when a lobby session is about to time out."
      >
        <div class="max-w-lg">
          <.solo_lobby
            id="lobby-inactivity"
            nickname="Troll"
            games={@sample_games}
            session_status="lobby"
            inactivity_warning={true}
          />
        </div>
        <.code_example>
          &lt;.solo_lobby
          id="lobby-inactivity"
          nickname="Troll"
          games=&#123;@games&#125;
          session_status="lobby"
          inactivity_warning=&#123;true&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
