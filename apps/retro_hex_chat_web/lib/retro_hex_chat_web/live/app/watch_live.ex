defmodule RetroHexChatWeb.App.WatchLive do
  @moduledoc """
  A P2P match, watched: `/watch/:token`.

  Open to anybody, an account or not — watching asks nothing of anyone, and a
  match offered in the open (a match link, `/lfg`) is a match played in the
  open. A session one person invited another to cannot be watched, and says
  so.

  The page knows only what the session says about its games — one starting,
  one ending, the session closing — on `Topics.lobby_watch/1`. The match
  itself is drawn in the browser, from the host's snapshots relayed by
  `SpectateChannel` (`SpectateCanvasHook`); this process never sees a frame.
  Each game gets a canvas of its own, keyed by when it started, so the next
  match after a rematch starts on a clean engine.

  The page counts itself among the people watching (`Games.Watchers`), and
  says how many there are. Between games, and after the last one, it offers
  the other matches being played now — the page is never a dead end.
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.LiveMatch
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Result
  alias RetroHexChat.Games.Watchers
  alias RetroHexChat.Lobby
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Components.UI.GameResultCard
  alias RetroHexChatWeb.Components.UI.LiveMatch
  alias RetroHexChatWeb.Icons

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(%{"token" => token}, _session, socket) do
    with {:ok, session} <- Lobby.get_session(token),
         true <- Lobby.watchable?(session),
         {:ok, summary} <- Lobby.session_summary(token) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.lobby_watch(token))
        Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.lobby_watchers(token))
        :ok = Watchers.watch(token)
      end

      {:ok,
       assign(socket,
         page_title: dgettext("games", "Watching a match"),
         token: token,
         watchable?: true,
         players: [summary.created_by, summary.peer],
         player_locales:
           NickLocales.for_nicks(Enum.reject([summary.created_by, summary.peer], &is_nil/1)),
         round: 0,
         watchers: Watchers.count(token)
       )
       |> assign_game(Lobby.current_game(token) || %{status: "idle", game_id: nil})}
    else
      _not_watchable ->
        {:ok,
         assign(socket,
           page_title: dgettext("games", "Watching a match"),
           token: token,
           watchable?: false,
           players: [],
           player_locales: %{},
           round: 0,
           watchers: 0,
           status: "closed",
           game_id: nil,
           result: nil,
           others: others(token)
         )}
    end
  end

  @impl true
  @spec handle_info(term(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_info({:watch_game, payload}, socket), do: {:noreply, assign_game(socket, payload)}

  def handle_info(%{event: "presence_diff"}, socket),
    do: {:noreply, assign(socket, :watchers, Watchers.count(socket.assigns.token))}

  # A new game gets a new canvas, so its engine starts from nothing.
  defp assign_game(socket, %{status: "playing"} = game) do
    assign(socket,
      status: "playing",
      game_id: game.game_id,
      result: nil,
      round: socket.assigns.round + 1,
      others: []
    )
  end

  defp assign_game(socket, game) do
    assign(socket,
      status: game.status,
      game_id: Map.get(game, :game_id) || socket.assigns[:game_id],
      result: Map.get(game, :result),
      others: others(socket.assigns.token)
    )
  end

  # The matches somebody who came for this one could watch instead.
  defp others(token) do
    Activity.live_matches()
    |> Enum.reject(&(&1.token == token))
    |> Enum.take(5)
    |> LiveMatch.put_player_locales()
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="bg-background text-text font-system flex h-screen flex-col">
      <.desktop id="watch-desktop" persist_key="watch" class="flex-1" data-testid="watch-desktop">
        <.desktop_window
          id="watch-match"
          title={window_title(@game_id)}
          pinned
          default_maximized
          body_class="h-full min-h-0 p-2"
          data-testid="watch-window"
        >
          <:icon>
            <Icons.game_icon :if={@game_id} game_id={@game_id} class="h-4 w-4" />
            <Icons.icon_watching :if={!@game_id} class="h-4 w-4" />
          </:icon>
          <:status>
            <.window_status_bar_field grow>
              <span data-testid="watch-status">{status_label(@status)}</span>
            </.window_status_bar_field>
            <.window_status_bar_field :if={@watchable?}>
              <span data-testid="watch-watchers">{LiveMatch.watchers_label(@watchers)}</span>
            </.window_status_bar_field>
            <.window_status_bar_field :if={@players != []}>
              <.match_players players={@players} locales={@player_locales} />
            </.window_status_bar_field>
          </:status>

          <div class="flex h-full min-h-0 flex-col gap-2">
            <div
              :if={@watchable? and @status == "playing" and @game_id}
              id={"watch-canvas-#{@round}"}
              phx-hook="SpectateCanvasHook"
              phx-update="ignore"
              data-token={@token}
              data-game-id={@game_id}
              data-frames="0"
              class="shadow-retro-field relative flex min-h-[220px] flex-1 items-center justify-center overflow-hidden bg-black p-1"
              data-testid="watch-canvas"
            >
              <canvas
                width="640"
                height="480"
                class="aspect-[4/3] h-auto max-h-full w-full max-w-[720px] bg-black"
              >
              </canvas>
              <div class="game-canvas__stub absolute inset-0 flex items-center justify-center bg-black text-xs font-bold text-white">
                {dgettext("games", "Waiting for the first frame...")}
              </div>
            </div>

            <div
              :if={not (@watchable? and @status == "playing")}
              class="flex min-h-[220px] flex-1 flex-col items-center justify-center gap-retro-8 bg-white p-retro-12 text-center shadow-retro-field"
              data-testid="watch-idle"
            >
              <Icons.game_icon :if={@game_id} game_id={@game_id} class="h-16 w-16" />
              <p class="text-sm font-bold">{idle_text(@watchable?, @status)}</p>
              <p :if={@result} class="text-sm" data-testid="watch-result">
                {result_text(@result, @players)}
              </p>

              <div :if={@others != []} class="mt-retro-8 text-sm" data-testid="watch-others">
                <p class="font-bold">{dgettext("games", "Live now")}</p>
                <ul class="space-y-1">
                  <li :for={match <- @others}><.live_match_link match={match} /></li>
                </ul>
              </div>
            </div>

            <div :if={@game_id} class="flex flex-wrap items-center gap-retro-8 text-xs">
              <%!-- The game's home: every way to play it, from the computer to
                    a seat in its channel. --%>
              <.link href={Paths.game_page_path(@game_id)} class="underline" data-testid="watch-play">
                {dgettext("games", "Play %{game} yourself", game: GameResultCard.game_title(@game_id))}
              </.link>
              <.link
                href={Paths.chat_path(Catalog.channel_name(@game_id))}
                class="underline"
                data-testid="watch-channel"
              >
                {Catalog.channel_name(@game_id)}
              </.link>
            </div>
          </div>
        </.desktop_window>
      </.desktop>
    </div>
    """
  end

  defp window_title(nil), do: dgettext("games", "Watching a match")

  defp window_title(game_id),
    do: dgettext("games", "Watching %{game}", game: GameResultCard.game_title(game_id))

  defp status_label("playing"), do: dpgettext("games", "match", "Live")
  defp status_label("finished"), do: dgettext("games", "Match over")
  defp status_label("closed"), do: dpgettext("games", "match", "Ended")
  defp status_label(_waiting), do: dgettext("games", "Waiting")

  defp idle_text(false, _status), do: dgettext("games", "This match cannot be watched.")
  defp idle_text(true, "finished"), do: dgettext("games", "Match over")
  defp idle_text(true, "closed"), do: dgettext("games", "The players have left.")
  defp idle_text(true, _waiting), do: dgettext("games", "Waiting for the next game.")

  # The host plays the first side; the session names its creator first, and
  # the creator hosts a match it offered.
  defp result_text(%Result{} = result, [host, guest | _rest]) do
    GameResultCard.score_line(%{
      p1_nickname: host,
      p2_nickname: guest,
      p1_score: result.p1_score,
      p2_score: result.p2_score
    })
  end

  defp result_text(_result, _players), do: nil
end
