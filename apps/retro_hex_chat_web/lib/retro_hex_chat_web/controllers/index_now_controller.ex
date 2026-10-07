defmodule RetroHexChatWeb.IndexNowController do
  @moduledoc """
  Serves the IndexNow key at `/indexnow.txt`.

  An engine that receives a list of changed URLs fetches this file and compares
  it with the key in the request: a match proves the list came from this host.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.SEO.IndexNow

  @spec key(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def key(conn, _params) do
    case IndexNow.key() do
      "" ->
        send_resp(conn, 404, "Not found")

      key ->
        conn
        |> put_resp_content_type("text/plain")
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> send_resp(200, key)
    end
  end
end
