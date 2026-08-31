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
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Arcade

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"game" => game_id}) do
    case Arcade.get_game(game_id) do
      {:ok, game} ->
        redirect(conn, external: Arcade.game_url(game))

      {:error, :not_found} ->
        # The same answer a dead share link gets, for the same reason: an
        # address that names nothing should not be an oracle for what exists.
        redirect(conn, to: ~p"/chat")
    end
  end
end
