defmodule RetroHexChatWeb.App.PlayLive do
  @moduledoc """
  Retro Games, as a surface of its own.

  One module, two mounts: this is the page at `/play/:game` and it is also what
  the chat's Retro Games window renders. Nothing about a game is written twice —
  the difference between the two is where the process hangs, not what it does.

  The state is the same shape the chat window always had: which game is chosen,
  how hard the opponent plays, whether the canvas has reported for duty, and how
  the last match ended. All of it is per-person and per-tab, so none of it is
  persisted.
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.RetroGamesPanel
  import RetroHexChatWeb.Components.UI.ShareBar
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @difficulties ~w(easy normal hard)

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(
        embedded?: session["embedded"] == true,
        nickname: session["nickname"] || socket.assigns[:surface_nickname],
        share_url: nil,
        games: Catalog.list_solo_games(),
        status: "library",
        selected_game: nil,
        difficulty: "normal",
        canvas_ready: false,
        result: nil,
        error_message: nil
      )
      |> select_from_path(params)

    {:ok, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(%{embedded?: true} = assigns) do
    ~H"""
    <div class="h-full">
      <.games_body {assigns} />
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <%!-- Same shell every other desktop screen uses: the workspace only has a
          height because something above it does. Without this the window
          manager runs, opens the window, and lays it out 1280x0. --%>
    <div class="bg-background text-text font-system flex h-screen flex-col">
      <.desktop
        id="play-desktop"
        persist_key="play"
        class="flex-1"
        data-testid="play-desktop"
      >
        <.desktop_window
          id="retro-games"
          title={dgettext("games", "Retro Games")}
          pinned
          default_maximized
          body_class="h-full min-h-0 p-2"
          data-testid="retro-games-window"
        >
          <:icon><Icons.icon_game_pong class="h-4 w-4" /></:icon>
          <%!-- The way back is always on screen. Someone who arrived from a
              shared link has no chat tab to return to, so this is a link and
              not a focus request — the full open/focus decision needs to know
              what else the person has open, which is a later wave. --%>
          <:status>
            <.window_status_bar_field grow>
              <.link navigate={~p"/chat"} data-testid="play-back-to-chat">
                ← {dgettext("games", "Chat")}
              </.link>
            </.window_status_bar_field>
          </:status>
          <.games_body {assigns} />
        </.desktop_window>
      </.desktop>
    </div>
    """
  end

  # The chat renders this same LiveView inside its own Retro Games window, so
  # the body is shared and the chrome is not: embedded, the window around it
  # already belongs to the chat's desktop.
  defp games_body(assigns) do
    ~H"""
    <div class="flex h-full min-h-0 flex-col gap-2">
      <.share_bar
        :if={@selected_game}
        url={@share_url}
        available={sharable?(@nickname)}
        on_share="share_game"
      />
      <.retro_games_panel
        id="retro-games-panel"
        games={@games}
        status={@status}
        selected_game={@selected_game}
        difficulty={@difficulty}
        canvas_ready={@canvas_ready}
        result={@result}
        error_message={@error_message}
        target={nil}
        class="min-h-0 flex-1"
      />
    </div>
    """
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("retro_games_select", %{"game-id" => game_id}, socket) do
    {:noreply, select_game(socket, game_id)}
  end

  def handle_event("retro_games_set_difficulty", %{"difficulty" => difficulty}, socket) do
    {:noreply, assign(socket, difficulty: normalize_difficulty(difficulty))}
  end

  def handle_event("retro_games_start_ai", _params, socket) do
    {:noreply, begin_match(socket)}
  end

  def handle_event("retro_games_play_again", _params, socket) do
    {:noreply,
     assign(socket, status: "ready", canvas_ready: false, result: nil, error_message: nil)}
  end

  def handle_event("retro_games_back", _params, socket) do
    {:noreply, back_to_library(socket)}
  end

  # Minting is a deliberate act, not a side effect of opening a game: a link per
  # window opened would fill the table with addresses nobody ever sent.
  def handle_event("share_game", _params, %{assigns: %{selected_game: %{id: game_id}}} = socket) do
    with {:ok, user_id} <- SessionHelpers.resolve_user_id(socket.assigns.nickname || ""),
         {:ok, link} <-
           ShareLinks.create(%{
             kind: "play",
             target: %{"game_id" => game_id},
             creator_id: user_id,
             creator_nick: socket.assigns.nickname
           }) do
      {:noreply, assign(socket, share_url: SEO.site_url("/join/" <> link.slug))}
    else
      _unavailable -> {:noreply, socket}
    end
  end

  def handle_event("share_game", _params, socket), do: {:noreply, socket}

  # The canvas hook reports to whichever LiveView owns its element, which is
  # this one in both mounts.
  def handle_event("retro_game_canvas_ready", params, socket) do
    {:noreply, mark_canvas_ready(socket, game_id(params))}
  end

  def handle_event("retro_game_result", params, socket) do
    {:noreply, finish_match(socket, params)}
  end

  def handle_event("retro_game_error", params, socket) do
    {:noreply, fail_match(socket, params)}
  end

  # Only the routed mount has params at all: a child LiveView is handed
  # `:not_mounted_at_router`, which falls through to the library.
  defp select_from_path(socket, %{"game" => game_id}) when is_binary(game_id) do
    select_game(socket, game_id)
  end

  defp select_from_path(socket, _params), do: socket

  defp select_game(socket, game_id) do
    with true <- Catalog.solo_game_id?(game_id),
         {:ok, game} <- Catalog.get_game(game_id) do
      socket
      |> stop_current_unless(game_id)
      |> assign(
        status: "ready",
        selected_game: game,
        canvas_ready: false,
        result: nil,
        error_message: nil,
        share_url: nil
      )
    else
      _ -> back_to_library(socket)
    end
  end

  defp begin_match(
         %{assigns: %{status: "ready", canvas_ready: true, selected_game: game}} = socket
       )
       when is_map(game) do
    socket
    |> assign(status: "playing", result: nil, error_message: nil)
    |> push_event("retro_game_begin", %{game_id: game.id, difficulty: socket.assigns.difficulty})
  end

  defp begin_match(socket), do: socket

  defp mark_canvas_ready(%{assigns: %{selected_game: %{id: game_id}}} = socket, game_id) do
    if socket.assigns.status in ["ready", "playing"] do
      assign(socket, canvas_ready: true)
    else
      socket
    end
  end

  defp mark_canvas_ready(socket, _game_id), do: socket

  defp finish_match(%{assigns: %{selected_game: %{id: game_id}}} = socket, result) do
    if game_id(result) == game_id do
      assign(socket, status: "finished", canvas_ready: false, result: result)
    else
      socket
    end
  end

  defp finish_match(socket, _result), do: socket

  defp fail_match(%{assigns: %{selected_game: %{id: game_id}}} = socket, payload) do
    if game_id(payload) == game_id do
      assign(socket,
        status: "error",
        canvas_ready: false,
        error_message: dgettext("games", "The game engine could not be loaded."),
        result: nil
      )
    else
      socket
    end
  end

  defp fail_match(socket, _payload), do: socket

  defp back_to_library(socket) do
    socket
    |> stop_current_unless(nil)
    |> assign(
      status: "library",
      selected_game: nil,
      canvas_ready: false,
      result: nil,
      error_message: nil,
      share_url: nil
    )
  end

  defp stop_current_unless(%{assigns: %{selected_game: %{id: current_id}}} = socket, next_id)
       when current_id != next_id do
    push_event(socket, "retro_game_stop", %{game_id: current_id})
  end

  defp stop_current_unless(socket, _next_id), do: socket

  defp normalize_difficulty(difficulty) when difficulty in @difficulties, do: difficulty
  defp normalize_difficulty(_difficulty), do: "normal"

  # Only a registered nickname can mint a link: the record carries who made it,
  # and a link nobody is accountable for is one nobody can be asked about.
  defp sharable?(nickname) when is_binary(nickname) and nickname != "" do
    match?({:ok, _id}, SessionHelpers.resolve_user_id(nickname))
  end

  defp sharable?(_nickname), do: false

  defp game_id(%{"game_id" => game_id}), do: game_id
  defp game_id(%{game_id: game_id}), do: game_id
  defp game_id(_params), do: nil
end
