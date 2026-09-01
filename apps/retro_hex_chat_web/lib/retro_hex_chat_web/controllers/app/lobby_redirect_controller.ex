defmodule RetroHexChatWeb.App.LobbyRedirectController do
  @moduledoc """
  Legacy `/lobby/:token` links — old invite PMs, old bookmarks — land at the
  session they name.

  They used to land in the chat with the token thrown away, on the reasoning
  that the chat re-hydrates whatever session you are in. That was true and it
  was not the same thing: it worked only for the two people already in the
  session, and only for the one they happened to be in. `/p2p/:token` is the
  address the token was always naming, and it refuses a stranger with its own
  sentence rather than silently landing them somewhere else.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChatWeb.App.Paths

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"token" => token}) when is_binary(token) and token != "" do
    redirect(conn, to: Paths.p2p_path(token))
  end

  def show(conn, _params), do: redirect(conn, to: Paths.chat_path())
end
