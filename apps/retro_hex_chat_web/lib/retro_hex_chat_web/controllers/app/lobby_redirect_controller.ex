defmodule RetroHexChatWeb.App.LobbyRedirectController do
  @moduledoc """
  Legacy `/lobby/:token` links (old invite PMs, bookmarks) land in the chat,
  where the P2P session now lives: the chat re-hydrates the user's active
  session on mount, so a participant following an old link arrives attached.
  """
  use RetroHexChatWeb, :controller

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params), do: redirect(conn, to: ~p"/chat")
end
