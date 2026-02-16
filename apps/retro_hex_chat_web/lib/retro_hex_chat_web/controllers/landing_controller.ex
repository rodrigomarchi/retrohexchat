defmodule RetroHexChatWeb.LandingController do
  @moduledoc """
  Serves the public landing page at `/landing`.

  This is a standard Phoenix controller (not LiveView) for optimal SEO
  and performance — no WebSocket, no LiveView JS overhead.
  """
  use RetroHexChatWeb, :controller

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, :index)
  end
end
