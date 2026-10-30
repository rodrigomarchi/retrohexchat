defmodule RetroHexChatWeb.GoneController do
  @moduledoc """
  Answers addresses that were removed for good.

  A 410 tells a search engine to drop the page at once, where a 404 leaves it
  to come back and check for weeks. A person who followed an old link gets the
  site's error screen, which is what tells us they came.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChatWeb.ErrorHTML
  alias RetroHexChatWeb.SEO

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    conn
    |> put_resp_header("x-robots-tag", SEO.noindex_content())
    |> put_status(:gone)
    |> put_view(html: ErrorHTML)
    |> put_format("html")
    |> render(:"410")
  end
end
