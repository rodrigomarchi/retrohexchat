defmodule RetroHexChatWeb.HealthController do
  use RetroHexChatWeb, :controller

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
