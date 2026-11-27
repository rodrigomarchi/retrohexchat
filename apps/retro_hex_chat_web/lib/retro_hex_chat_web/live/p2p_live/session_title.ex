defmodule RetroHexChatWeb.P2PLive.SessionTitle do
  @moduledoc """
  What a session's own page is called: the game being played in it, or the
  game its link named until another is played, with who is on the other end.
  A session that played a Sprint and then a Night Race is titled after the
  Night Race while it runs, not after the link somebody followed to the Sprint.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  import Phoenix.Component, only: [assign: 3]

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Games.Catalog

  @doc "The title for a session (or none yet) and the game it is about (or none)."
  @spec title(map() | nil, map() | nil) :: String.t()
  def title(%{peer_nick: peer}, %{name: game}) when is_binary(peer) and peer != "",
    do: dgettext("chat", "%{game} · %{peer}", game: game, peer: peer)

  def title(_p2p, %{name: game}), do: dgettext("chat", "%{game} · match", game: game)

  def title(%{peer_nick: peer}, _game) when is_binary(peer) and peer != "",
    do: dgettext("chat", "P2P · %{peer}", peer: peer)

  def title(_p2p, _game), do: dgettext("chat", "P2P Session")

  @doc "The game a session's page is about: the one played in it, else the one its link named."
  @spec game(map()) :: map() | nil
  def game(assigns), do: assigns[:session_game] || assigns[:match_game]

  @doc """
  A game has started in the session: on the session's own page (the one that
  keeps the link's game) it becomes what the window and the tab are titled
  after. Other pages that follow the session are left as they are.
  """
  @spec game_started(Socket.t(), String.t()) :: Socket.t()
  def game_started(%Socket{assigns: assigns} = socket, game_id) do
    with true <- Map.has_key?(assigns, :match_game),
         {:ok, game} <- Catalog.get_game(game_id) do
      socket
      |> assign(:session_game, game)
      |> assign(:page_title, title(assigns[:p2p_session], game))
    else
      _not_this_page_or_game -> socket
    end
  end
end
