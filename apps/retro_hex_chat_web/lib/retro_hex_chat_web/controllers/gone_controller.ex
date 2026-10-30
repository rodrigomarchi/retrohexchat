defmodule RetroHexChatWeb.GoneController do
  @moduledoc """
  Answers addresses that were removed for good.

  A 410 tells a search engine to drop the page at once, where a 404 leaves it
  to come back and check for weeks.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChatWeb.SEO

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    conn
    |> put_resp_header("x-robots-tag", SEO.noindex_content())
    |> put_resp_content_type("text/plain")
    |> send_resp(:gone, "Gone")
  end
end
