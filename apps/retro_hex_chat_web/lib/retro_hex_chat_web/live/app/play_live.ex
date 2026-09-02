defmodule RetroHexChatWeb.App.PlayLive do
  @moduledoc """
  Retro Games, at an address of its own.

  The page at `/play` and `/play/:game`, and the only place the catalogue is
  rendered. The chat used to draw this same module into a window of its own;
  it does not any more, and the chat's Games menu is a plain link here.

  A catalogue is not a room — there is nothing to create and nothing to
  announce — so this is the one screen with an address that posts no card.

  The state is the same shape it always had: which game is chosen, how hard the
  opponent plays, whether the canvas has reported for duty, and how the last
  match ended. All of it is per-person and per-tab, so none of it is persisted.
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.RetroGamesPanel
  import RetroHexChatWeb.Components.UI.ShareBar
  import RetroHexChatWeb.Components.UI.SurfaceTabLink
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Lobby
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Components.UI.Button
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.OpenSurfaces
  alias RetroHexChatWeb.ShareLinkRef

  @difficulties ~w(easy normal hard)

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(
        nickname: session["nickname"] || socket.assigns[:surface_nickname],
        share_url: nil,
        share_slug: nil,
        games: Catalog.list_solo_games(),
        status: "library",
        selected_game: nil,
        difficulty: "normal",
        canvas_ready: false,
        result: nil,
        error_message: nil,
        match_error: nil
      )
      |> OpenSurfaces.attach(session["nickname"] || socket.assigns[:surface_nickname])
      |> select_from_path(params)

    {:ok, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <%!-- Same shell every other desktop screen uses: the workspace only has a
          height because something above it does. Without this the window
          manager runs, opens the window, and lays it out 1280x0. --%>
    <div class="bg-background text-text font-system flex h-screen flex-col">
      <%!-- This tab answers when the chat asks for it by address. --%>
      <div id="surface-presence" phx-hook="SurfacePresenceHook" class="hidden"></div>
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
          <%!-- The way back is always on screen. --%>
          <:status>
            <.window_status_bar_field grow>
              <.back_to_chat
                open?={OpenSurfaces.open?(@open_surface_paths, Paths.chat_path())}
                testid="play-back-to-chat"
              />
            </.window_status_bar_field>
          </:status>
          <.games_body {assigns} />
        </.desktop_window>
      </.desktop>
    </div>
    """
  end

  defp games_body(assigns) do
    ~H"""
    <div class="flex h-full min-h-0 flex-col gap-2">
      <div :if={@selected_game} class="flex flex-wrap items-center gap-2">
        <.share_bar
          url={@share_url}
          available={sharable?(@nickname)}
          on_share="share_game"
          on_revoke="revoke_game"
          class="min-w-0 flex-1"
        />
        <%!-- Where a match is born, and deliberately inside the game rather
              than beside it: you decide to play with somebody while looking at
              what you would play. The room comes first and the link second —
              opening a game does not mint an address, pressing Share does. --%>
        <Button.button
          :if={sharable?(@nickname)}
          type="button"
          phx-click="create_match"
          data-testid="play-create-match"
        >
          <:icon><Icons.icon_protocol_p2p_compact class="h-4 w-4" /></:icon>
          {dgettext("games", "Play with someone")}
        </Button.button>
        <p :if={@match_error} class="text-warning text-sm" data-testid="play-match-error">
          {@match_error}
        </p>
      </div>
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
      {:noreply, assign(socket, share_url: ShareLinkRef.url(link.slug), share_slug: link.slug)}
    else
      _unavailable -> {:noreply, socket}
    end
  end

  def handle_event("share_game", _params, socket), do: {:noreply, socket}

  # Closing the address without closing the room. `ShareLinks` asks its own
  # policy who may — the creator, or an operator of the channel the link leads
  # into — so a screen that offers the button is not the thing deciding.
  def handle_event("revoke_game", _params, %{assigns: %{share_slug: slug}} = socket)
      when is_binary(slug) do
    case ShareLinks.revoke(slug, socket.assigns.nickname || "") do
      {:ok, _link} -> {:noreply, assign(socket, share_url: nil, share_slug: nil)}
      _refused -> {:noreply, socket}
    end
  end

  def handle_event("revoke_game", _params, socket), do: {:noreply, socket}

  # A match link needs a room to point at, and a room with an empty seat is
  # what the domain calls an open lobby. Creating it is not sharing it: the
  # address is minted in the room, by Share, the way every other surface in
  # this plan mints one.
  def handle_event("create_match", _params, %{assigns: %{selected_game: %{id: game_id}}} = socket) do
    with {:ok, user_id} <- SessionHelpers.resolve_user_id(socket.assigns.nickname || ""),
         {:ok, %{token: token}} <-
           Lobby.create_open_session(user_id, metadata: %{"game_id" => game_id}) do
      {:noreply, push_navigate(socket, to: Paths.play_match_path(game_id, token))}
    else
      {:error, message} when is_binary(message) ->
        {:noreply, assign(socket, match_error: message)}

      _unavailable ->
        {:noreply,
         assign(socket, match_error: dgettext("games", "You cannot start a match right now."))}
    end
  end

  def handle_event("create_match", _params, socket), do: {:noreply, socket}

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
        share_url: nil,
        share_slug: nil,
        match_error: nil
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
      share_url: nil,
      share_slug: nil,
      match_error: nil
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
