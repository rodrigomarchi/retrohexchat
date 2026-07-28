defmodule RetroHexChatWeb.CallsHealthController do
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Calls.Health

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    result = Health.check()

    conn
    |> put_status(Health.http_status(result))
    |> json(result)
  end
end
