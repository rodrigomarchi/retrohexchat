defmodule RetroHexChatWeb.App.LobbyLive.Components.GameIsland do
  @moduledoc """
  Game island — owner of the lobby's game state (the catalog, the active game and
  the incoming/outgoing proposal) and the body of the "Games" window.

  The island drives its own window: it pushes `window_command` to open the Games
  window on a proposal or game start and to close it when the game ends, and it
  pushes the canvas hook's `lobby_game_start`/`lobby_game_end` lifecycle events
  (C3). Whenever the game becomes active or idle it mirrors a minimal summary to
  the host — `send(self(), {:feature_summary, :game, %{active?: ...}})` — so the
  taskbar badge reads it without reaching into the game state (C2).

  Game PubSub stays subscribed on the host, which forwards each event here via
  `send_update/2`. The proposal/response/quit context calls
  (`Lobby.propose_game`/`respond_game`/`end_game`) keep firing on the host, where
  the session identity lives; their result flows back through PubSub, so the
  island needs no token/user_id of its own.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Lobby.GamePanel

  alias RetroHexChat.Games.Catalog

  @id "lobby-game"
  @idle %{status: "idle", game_id: nil, is_host: false}

  @doc "Stable DOM/component id used by the host for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       game: @idle,
       game_request: nil,
       game_outgoing: false,
       games: Catalog.list_games(),
       connected: false,
       peer_nick: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: action} = assigns, socket) do
    {:ok, socket |> assign_context(assigns) |> handle_action(action)}
  end

  def update(assigns, socket), do: {:ok, assign_context(socket, assigns)}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.game_panel
        connected={@connected}
        game={@game}
        game_request={@game_request}
        game_outgoing={@game_outgoing}
        games={@games}
        peer_nick={@peer_nick}
      />
    </div>
    """
  end

  @spec assign_context(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_context(socket, assigns) do
    assign(socket,
      connected: Map.get(assigns, :connected, socket.assigns.connected),
      peer_nick: Map.get(assigns, :peer_nick, socket.assigns.peer_nick)
    )
  end

  @spec handle_action(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  defp handle_action(socket, {:request, request, outgoing}) do
    socket
    |> assign(game_request: request, game_outgoing: outgoing)
    |> push_event("window_command", %{action: "open", id: "game"})
  end

  defp handle_action(socket, :request_declined) do
    assign(socket, game_request: nil, game_outgoing: false)
  end

  defp handle_action(socket, {:playing, game_id, is_host}) do
    socket
    |> assign(
      game: %{status: "playing", game_id: game_id, is_host: is_host},
      game_request: nil,
      game_outgoing: false
    )
    |> push_event("lobby_game_start", %{game_id: game_id, is_host: is_host})
    |> push_event("window_command", %{action: "open", id: "game"})
    |> summarize()
  end

  defp handle_action(socket, :idle) do
    socket
    |> assign(game: @idle)
    |> push_event("lobby_game_end", %{})
    |> push_event("window_command", %{action: "close", id: "game"})
    |> summarize()
  end

  defp handle_action(socket, :canvas_ready) do
    game = socket.assigns.game

    if game.status == "playing" do
      push_event(socket, "lobby_game_start", %{game_id: game.game_id, is_host: game.is_host})
    else
      socket
    end
  end

  defp handle_action(socket, :end_game) do
    socket
    |> assign(game_request: nil, game_outgoing: false)
    |> push_event("window_command", %{action: "close", id: "game"})
  end

  # The host owns the taskbar read-model: bubble a minimal summary up so the badge
  # tracks the game without reading the island's full state.
  @spec summarize(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp summarize(socket) do
    send(self(), {:feature_summary, :game, %{active?: socket.assigns.game.status == "playing"}})
    socket
  end
end
