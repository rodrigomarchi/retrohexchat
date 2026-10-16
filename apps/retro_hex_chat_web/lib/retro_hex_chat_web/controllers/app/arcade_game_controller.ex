defmodule RetroHexChatWeb.App.ArcadeGameController do
  @moduledoc """
  The arcade's own address.

  An arcade game is a WebAssembly bundle on a static host, so the URL that
  actually runs it belongs to that host and changes with it. This route is the
  name we can give out: `/play/arcade/:game` is ours, it is stable, and it is
  the thing somebody can paste. Where the bundle lives is a deployment detail
  the address does not have to carry.

  It is a redirect and not a page because there is nothing of ours to draw: the
  game *is* the other origin. Opening it goes through an anchor with
  `rel="noopener"` so the tab gets its own event loop — measured at 1203 ms
  against 12 ms — which also means there is no window handle left to poll.

  That other origin is also why this tab is the one thing the cross-tab
  coordination cannot reach: there is no LiveView here for
  `RetroHexChat.Surfaces` to monitor, and `BroadcastChannel` is per origin. So
  an arcade session ends the way a session ends — **End Session**, or the
  inactivity timeout the `SoloSessionServer` already keeps — and never because a
  window vanished.

  It asks what the arcade inside the chat asks: a signed-in, identified
  nickname. Anybody else — a visitor, a session that never proved its name —
  lands in the chat with the sign-in window open on games, and comes back to
  the game in the chat's arcade once signed in. A banned nickname goes where a
  ban always sends it.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Arcade
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionNickname

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"game" => game_id}) do
    session = get_session(conn)

    case SessionNickname.resolve(session) do
      {:ok, nickname} ->
        if SessionNickname.identified?(session, nickname),
          do: open_game(conn, game_id),
          else: ask_to_sign_in(conn, game_id)

      :banned ->
        redirect(conn, to: ~p"/connect?reason=banned")

      :visitor ->
        ask_to_sign_in(conn, game_id)
    end
  end

  defp open_game(conn, game_id) do
    case Arcade.get_game(game_id) do
      {:ok, game} ->
        redirect(conn, external: Arcade.game_url(game))

      {:error, :not_found} ->
        # The same answer a dead share link gets, for the same reason: an
        # address that names nothing should not be an oracle for what exists.
        redirect(conn, to: ~p"/chat")
    end
  end

  # Not looked up first: whether the game exists is the arcade's to say, to
  # somebody allowed to ask.
  defp ask_to_sign_in(conn, game_id) do
    redirect(conn, to: Paths.visitor_sign_in_path(:games, Paths.chat_arcade_path(game_id)))
  end
end
