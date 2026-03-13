defmodule RetroHexChatWeb.ShowcaseLive.Games.GameLobbyPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.GameLobby
  import RetroHexChatWeb.Components.UI.GameSessionEnded
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChat.Games.Catalog

  @local_info %{
    browser: "Chrome 145.0",
    os: "macOS 10.15",
    screen: "2560x1440",
    language: "en-US",
    timezone: "America/Sao_Paulo",
    cores: 14,
    color_depth: 24
  }

  @peer_info %{
    browser: "Firefox 148.0",
    os: "Linux Ubuntu",
    screen: "1920x1080",
    language: "pt-BR",
    timezone: "America/Sao_Paulo",
    cores: 8,
    color_depth: 30
  }

  @impl true
  def mount(_params, _session, socket) do
    games = Catalog.list_games() |> Enum.take(6)

    {:ok,
     assign(socket,
       page_title: "Game Lobby",
       active_page: "game-lobby",
       games: games
     )}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:local_info, @local_info)
      |> assign(:peer_info, @peer_info)

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
          local_info={@local_info}
          peer_info={@peer_info}
        />
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
          game_request={%{game_id: "hex_pong", game_name: "Hex Pong", requester_nick: "alice"}}
          session_status="Waiting for acceptance"
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title="Waiting State (Guest)"
        description="Guest waits for the host to choose a game."
      >
        <.game_lobby
          id="game-lobby-guest-waiting"
          nickname="bob"
          peer_nick="alice"
          role={:peer}
          games={@games}
          session_status="Waiting for game selection"
          local_info={@local_info}
          peer_info={@peer_info}
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
          game_request={%{game_id: "hex_pong", game_name: "Hex Pong", requester_nick: "alice"}}
          session_status="Game request received"
          local_info={@local_info}
          peer_info={@peer_info}
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
          local_info={@local_info}
          peer_info={@peer_info}
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
          local_info={@local_info}
        />
      </.showcase_card>

      <h2 class="text-lg font-bold mb-3 mt-6">Game Session Ended</h2>

      <.showcase_card
        title="Game Over (with score)"
        description="Shown after a game finishes with final score and winner."
      >
        <.game_session_ended
          nickname="alice"
          peer="bob"
          reason="Game over."
          duration={185}
          game_name="Hex Pong"
          game_result={%{"score" => %{"p1" => 11, "p2" => 7}, "winner" => 1}}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title="Session Closed by User"
        description="Session closed by the other peer."
      >
        <.game_session_ended
          nickname="alice"
          peer="bob"
          reason="Session closed by user."
          duration={3723}
          local_info={@local_info}
          peer_info={@peer_info}
        />
      </.showcase_card>

      <.showcase_card
        title="Session Ended (no result)"
        description="Session expired before a game was played."
      >
        <.game_session_ended
          nickname="alice"
          peer="charlie"
          reason="Session expired due to inactivity."
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
