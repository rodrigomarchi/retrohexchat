defmodule RetroHexChatWeb.CharacterPortraitController do
  @moduledoc """
  Serves the face of a Space character: `/character-portrait/:version/:recipe`.

  The recipe is the character, so the address is the picture: the same recipe
  is the same face for everybody, and the catalog version in the path changes
  whenever the art does. That is what lets the answer be cached for a year and
  never revalidated. A recipe the art cannot compose is a 404, not a guess.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.VirtualSpace.CharacterCatalog
  alias RetroHexChatWeb.CharacterPortrait

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"version" => version, "recipe" => recipe}) do
    with true <- version == CharacterCatalog.version(),
         {:ok, png} <- CharacterPortrait.png(recipe) do
      conn
      |> put_resp_content_type("image/png", nil)
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> send_resp(200, png)
    else
      _ -> send_resp(conn, :not_found, "")
    end
  end
end
