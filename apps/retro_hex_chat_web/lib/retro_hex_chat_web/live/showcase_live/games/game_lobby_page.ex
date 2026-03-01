defmodule RetroHexChatWeb.ShowcaseLive.Games.GameLobbyPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.GameLobby
  import RetroHexChatWeb.ShowcaseHelpers

  @games [
    %{id: "pong", name: "Pong", icon: :pong},
    %{id: "tanks", name: "Tanks", icon: :tanks},
    %{id: "breakout", name: "Breakout", icon: :breakout},
    %{id: "space", name: "Space Invaders", icon: :space},
    %{id: "tennis", name: "Tennis", icon: :tennis},
    %{id: "boxing", name: "Boxing", icon: :boxing}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Game Lobby",
       active_page: "game-lobby",
       games: @games
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Game Lobby</h2>

      <.showcase_card
        title="Lobby State"
        description="Host sees the game picker grid and can invite the guest to play."
      >
        <.game_lobby
          id="game-lobby-host"
          nickname="alice"
          peer_nick="bob"
          role={:creator}
          games={@games}
          session_status="Waiting for game selection"
        />
        <.code_example>
          &lt;.game_lobby
          id="game-lobby"
          nickname="alice"
          peer_nick="bob"
          role=&#123;:creator&#125;
          games=&#123;@games&#125;
          on_select_game="select_game"
          on_close="leave_lobby"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Waiting State (Host)"
        description="Host sent a game request and is waiting for the guest to respond."
      >
        <.game_lobby
          id="game-lobby-waiting"
          nickname="alice"
          peer_nick="bob"
          role={:creator}
          games={@games}
          game_request={%{game_id: "Pong", requester_nick: "alice"}}
          session_status="Waiting for acceptance"
        />
      </.showcase_card>

      <.showcase_card
        title="Consent State (Guest)"
        description="Guest sees an accept/decline banner when the host requests a game."
      >
        <.game_lobby
          id="game-lobby-consent"
          nickname="bob"
          peer_nick="alice"
          role={:peer}
          games={@games}
          game_request={%{game_id: "Pong", requester_nick: "alice"}}
          session_status="Game request received"
        />
      </.showcase_card>

      <.showcase_card
        title="Inactivity Warning"
        description="Yellow warning bar appears when the lobby is about to close due to inactivity."
      >
        <.game_lobby
          id="game-lobby-inactive"
          nickname="alice"
          peer_nick="bob"
          role={:creator}
          games={@games}
          inactivity_warning={true}
          session_status="Lobby idle"
        />
      </.showcase_card>

      <.showcase_card
        title="Peer Offline"
        description="Lobby when the peer has gone offline."
      >
        <.game_lobby
          id="game-lobby-offline"
          nickname="alice"
          peer_nick="charlie"
          role={:creator}
          peer_online={false}
          games={[]}
          session_status="Peer disconnected"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
