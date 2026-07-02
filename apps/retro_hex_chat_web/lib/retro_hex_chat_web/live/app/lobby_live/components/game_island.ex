defmodule RetroHexChatWeb.App.LobbyLive.Components.GameIsland do
  @moduledoc """
  Game island — owner of the lobby's game state (the catalog, the active game and
  the incoming/outgoing proposal) and the body of the "Games" window.

  The Games window is server-managed: the island mounts only while the window is
  open, so every open starts from a fresh island. It pushes `window_command` open
  to restore/focus the window on a proposal or game start, asks the host to
  unmount it when the game ends — `send(self(), {:close_window, "game"})` — and
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
  alias RetroHexChatWeb.App.LobbyLive.Components.ChatIsland

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
    |> assign(game: @idle, game_request: request, game_outgoing: outgoing)
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
    send(self(), {:close_window, "game"})

    socket
    |> assign(game: @idle)
    |> push_event("lobby_game_end", %{})
    |> summarize()
  end

  # Both peers receive the finished broadcast: swap the frozen canvas for the
  # result card (the canvas hook unmounts and stops its engine), and drop a chat
  # line. The badge goes idle via summarize.
  defp handle_action(socket, {:result, result}) do
    game = socket.assigns.game

    socket
    |> assign(
      game: %{status: "finished", game_id: game.game_id, is_host: game.is_host, result: result},
      game_request: nil,
      game_outgoing: false
    )
    |> post_result_message(game.game_id, result)
    |> summarize()
  end

  defp handle_action(socket, :dismiss_result) do
    assign(socket, game: @idle)
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
    send(self(), {:close_window, "game"})
    assign(socket, game_request: nil, game_outgoing: false)
  end

  @spec post_result_message(Phoenix.LiveView.Socket.t(), String.t() | nil, map()) ::
          Phoenix.LiveView.Socket.t()
  defp post_result_message(socket, game_id, result) do
    name = game_name(socket.assigns.games, game_id)
    score = result["score"] || %{}
    p1 = score["p1"] || 0
    p2 = score["p2"] || 0

    message =
      dgettext("lobby", "Game over — %{game}: %{p1} × %{p2}", game: name, p1: p1, p2: p2)

    send_update(ChatIsland, id: ChatIsland.id(), system_message: message)
    socket
  end

  @spec game_name([map()], String.t() | nil) :: String.t()
  defp game_name(games, game_id) do
    case Enum.find(games, &(&1.id == game_id)) do
      %{name: name} -> name
      _ -> to_string(game_id)
    end
  end

  # The host owns the taskbar read-model: bubble a minimal summary up so the badge
  # tracks the game without reading the island's full state.
  @spec summarize(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp summarize(socket) do
    send(self(), {:feature_summary, :game, %{active?: socket.assigns.game.status == "playing"}})
    socket
  end
end
