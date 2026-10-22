defmodule RetroHexChatWeb.App.PlayLive do
  @moduledoc """
  A Retro Game, played against the computer, at an address of its own.

  The page at `/play/:game`, opened in a tab beside the desktop from the
  game's home (`Site.Pages.Game`), which stays open in the chat's tab: every
  other way to play the game — a partner, an invitation — starts there.
  `/play` without a game names nothing to play and sends the reader to the
  catalogue. From here a match room can be opened (Play with someone, or
  arriving at `?match=new` from the home) and the game shared.

  A game against the computer is not a room — there is nothing to create and
  nothing to announce — so this screen posts no card.

  The state is the same shape it always had: which game is chosen, how hard the
  opponent plays, whether the canvas has reported for duty, and how the last
  match ended. All of it is per-person and per-tab. The one thing that outlives
  the tab is a finished match of a signed-in player, which `Games.Results`
  writes down — timed from when this page started it, not from anything the
  canvas says.
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.RetroGamesPanel
  import RetroHexChatWeb.Components.UI.SurfaceTabLink
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Result
  alias RetroHexChat.Games.Results
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Components.UI.Button
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.OpenSurfaces
  alias RetroHexChatWeb.Live.ShareControl
  alias RetroHexChatWeb.ShareLinkRef

  @difficulties ~w(easy normal hard)

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(
        nickname: socket.assigns.surface_nickname,
        page_title: dgettext("games", "Retro Games"),
        share_url: nil,
        share_slug: nil,
        status: "ready",
        selected_game: nil,
        difficulty: "normal",
        canvas_ready: false,
        result: nil,
        record: nil,
        player: SessionHelpers.identified_player(session, socket.assigns.surface_nickname),
        host_id: host_id(socket.assigns.surface_nickname),
        sharable: SessionHelpers.sharable?(socket.assigns.surface_nickname),
        match_started_at: nil,
        error_message: nil,
        match_error: nil
      )
      |> OpenSurfaces.attach(socket.assigns.surface_nickname)
      |> select_from_path(params)
      |> open_match_if_asked(params)

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
            <%!-- The game's home and its channel: the rest of the game is
                  there — partners, rankings, who is playing now. --%>
            <.window_status_bar_field>
              <.link
                href={Paths.game_page_path(@selected_game.id)}
                class="underline"
                data-testid="play-game-home"
              >
                {Catalog.game_name(Catalog.base_id(@selected_game.id))}
              </.link>
            </.window_status_bar_field>
            <.window_status_bar_field>
              <.link
                href={Paths.chat_path(Catalog.channel_name(@selected_game.id))}
                class="underline"
                data-testid="play-game-channel"
              >
                {Catalog.channel_name(@selected_game.id)}
              </.link>
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
      <div class="flex flex-wrap items-center gap-2">
        <%!-- Where a match is born, and deliberately inside the game rather
              than beside it: you decide to play with somebody while looking at
              what you would play. The room comes first and the link second —
              opening a game does not mint an address, pressing Share does.

              Both are invitations, so they are read together and weighted:
              a match is the whole thing, a link is one way to hand it out. --%>
        <%!-- The match room seats only an identified nickname, so the
              button is offered to nobody it would turn away. --%>
        <Button.button
          :if={@host_id}
          type="button"
          phx-click="create_match"
          data-testid="play-create-match"
        >
          <:icon><Icons.icon_protocol_p2p_compact class="h-4 w-4" /></:icon>
          {dgettext("games", "Play with someone")}
        </Button.button>
        <.live_component
          module={ShareControl}
          id="share-game"
          url={@share_url}
          available={@sharable}
          on_share="share_game"
          on_revoke="revoke_game"
          variant="outline"
        />
        <p :if={@match_error} class="text-warning text-sm" data-testid="play-match-error">
          {@match_error}
        </p>
      </div>
      <.retro_games_panel
        id="retro-games-panel"
        status={@status}
        selected_game={@selected_game}
        difficulty={@difficulty}
        canvas_ready={@canvas_ready}
        result={@result}
        record={@record}
        ranked?={not is_nil(@player)}
        error_message={@error_message}
        class="min-h-0 flex-1"
      />
    </div>
    """
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("retro_games_set_difficulty", %{"difficulty" => difficulty}, socket) do
    if socket.assigns.status == "playing" do
      {:noreply, socket}
    else
      {:noreply, assign(socket, difficulty: normalize_difficulty(difficulty))}
    end
  end

  def handle_event("retro_games_start_ai", _params, socket) do
    {:noreply, begin_match(socket)}
  end

  def handle_event("retro_games_play_again", _params, socket) do
    {:noreply,
     assign(socket,
       status: "ready",
       canvas_ready: false,
       result: nil,
       record: nil,
       error_message: nil
     )}
  end

  # Ending a match leaves the game on screen, ready for another: the game's
  # home, where another game is chosen, is still open in the chat's tab.
  def handle_event(
        "retro_games_end",
        _params,
        %{assigns: %{selected_game: %{id: game_id}}} = socket
      ) do
    {:noreply,
     socket
     |> stop_playing()
     |> push_event("retro_game_stop", %{game_id: game_id})
     |> assign(status: "ready", canvas_ready: false, result: nil, record: nil, error_message: nil)}
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
  def handle_event("create_match", _params, socket), do: {:noreply, open_match(socket)}

  def handle_event("retro_game_canvas_ready", params, socket) do
    {:noreply, mark_canvas_ready(socket, game_id(params))}
  end

  def handle_event("retro_game_result", params, socket) do
    {:noreply, finish_match(socket, params)}
  end

  def handle_event("retro_game_error", params, socket) do
    {:noreply, fail_match(socket, params)}
  end

  # This page plays one game, named by its address. Without one there is
  # nothing to play here: the games are chosen in the catalogue.
  defp select_from_path(socket, %{"game" => game_id}) when is_binary(game_id) do
    select_game(socket, game_id)
  end

  defp select_from_path(socket, _params), do: to_catalogue(socket)

  defp to_catalogue(socket), do: redirect(socket, to: Paths.localized("/games"))

  # A game's home offers "a match room to copy a link from" as an address,
  # `?match=new`, so the room is opened here, once the page is live — a
  # crawler's or a preview's fetch opens nothing.
  defp open_match_if_asked(socket, %{"match" => "new"}) do
    if connected?(socket), do: open_match(socket), else: socket
  end

  defp open_match_if_asked(socket, _params), do: socket

  defp open_match(%{assigns: %{selected_game: %{id: game_id}, host_id: user_id}} = socket)
       when not is_nil(user_id) do
    case Lobby.create_open_session(user_id, metadata: %{"game_id" => game_id}) do
      {:ok, %{token: token}} -> push_navigate(socket, to: Paths.play_match_path(game_id, token))
      {:error, message} -> assign(socket, match_error: message)
    end
  end

  # Arriving at `?match=new` without a nickname the room would seat: said,
  # rather than a game against the computer the reader never asked for.
  defp open_match(%{assigns: %{selected_game: %{}}} = socket),
    do:
      assign(socket,
        match_error: dgettext("p2p", "You must be identified with NickServ to use P2P sessions.")
      )

  defp open_match(socket), do: socket

  defp select_game(socket, game_id) do
    with true <- Catalog.solo_game_id?(game_id),
         {:ok, game} <- Catalog.get_game(game_id) do
      assign(socket, selected_game: game)
    else
      _ -> to_catalogue(socket)
    end
  end

  defp begin_match(
         %{assigns: %{status: "ready", canvas_ready: true, selected_game: game}} = socket
       )
       when is_map(game) do
    :ok = Activity.playing(socket.assigns.nickname, game.id)

    socket
    |> assign(
      status: "playing",
      result: nil,
      record: nil,
      error_message: nil,
      match_started_at: DateTime.utc_now()
    )
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

  # Only a match this page started can finish: a result arriving in any other
  # state is a canvas reporting on a game nobody here began.
  defp finish_match(
         %{assigns: %{status: "playing", selected_game: %{id: game_id}}} = socket,
         payload
       ) do
    if game_id(payload) == game_id do
      result =
        case Result.normalize(game_id, payload) do
          {:ok, result} -> result
          {:error, _unreadable} -> nil
        end

      socket
      |> stop_playing()
      |> assign(
        status: "finished",
        canvas_ready: false,
        result: result,
        record: record_match(socket, payload)
      )
    else
      socket
    end
  end

  defp finish_match(socket, _payload), do: socket

  # A guest plays for fun: their name is nobody's to keep a score under.
  defp record_match(%{assigns: %{player: nil}}, _payload), do: nil

  defp record_match(%{assigns: assigns}, payload) do
    case Results.record(%{
           game_id: assigns.selected_game.id,
           origin: "ai",
           difficulty: assigns.difficulty,
           p1: assigns.player,
           payload: payload,
           started_at: assigns.match_started_at
         }) do
      {:ok, row} -> Results.card(row)
      {:error, _refused} -> nil
    end
  end

  defp fail_match(%{assigns: %{selected_game: %{id: game_id}}} = socket, payload) do
    if game_id(payload) == game_id do
      socket
      |> stop_playing()
      |> assign(
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

  # The match this page was playing is over, however it ended: the chat's user
  # list and the game's page stop saying this player is in one.
  defp stop_playing(%{assigns: %{status: "playing", nickname: nickname}} = socket) do
    :ok = Activity.stopped(nickname)
    socket
  end

  defp stop_playing(socket), do: socket

  defp normalize_difficulty(difficulty) when difficulty in @difficulties, do: difficulty
  defp normalize_difficulty(_difficulty), do: "normal"

  # Who may open a match room: the room's own door asks NickServ whether the
  # nickname is identified, so this asks the same question.
  defp host_id(nickname) when is_binary(nickname) and nickname != "" do
    with true <- NickServ.identified?(nickname),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname) do
      user_id
    else
      _unproved -> nil
    end
  end

  defp host_id(_nickname), do: nil

  defp game_id(%{"game_id" => game_id}), do: game_id
  defp game_id(%{game_id: game_id}), do: game_id
  defp game_id(_params), do: nil
end
