defmodule RetroHexChatWeb.CharacterPortraitController do
  @moduledoc """
  Serves the stills of a Space character: its face at
  `/character-portrait/:version/:recipe`, and the creator's pictures of its
  pieces at `/character-still/:view/:version/:recipe` — `figure`, the whole
  character, or `head`, all it wears on the head. A still is drawn only for
  somebody with a chat session, the only people who open the creator, and is
  kept by their browser alone.

  The recipe is the character, so the address is the picture: the same recipe
  is the same face for everybody, and the catalog version in the path changes
  whenever the art does. That is what lets the answer be cached for a year and
  never revalidated. A recipe the art cannot compose is a 404, not a guess.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.VirtualSpace.CharacterCatalog
  alias RetroHexChatWeb.CharacterPortrait

  # The views a still may be asked for by name; anything else is not one.
  @views %{"figure" => :figure, "head" => :head}

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, params), do: serve(conn, params, :portrait)

  @spec still(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def still(conn, %{"view" => view} = params) do
    with nickname when is_binary(nickname) and nickname != "" <-
           get_session(conn, :chat_nickname),
         {:ok, view} <- Map.fetch(@views, view) do
      serve(conn, params, view, "private")
    else
      _ -> send_resp(conn, :not_found, "")
    end
  end

  defp serve(conn, params, view, scope \\ "public")

  defp serve(conn, %{"version" => version, "recipe" => recipe}, view, scope) do
    with true <- version == CharacterCatalog.version(),
         {:ok, png} <- CharacterPortrait.png(recipe, view) do
      conn
      |> put_resp_content_type("image/png", nil)
      |> put_resp_header("cache-control", "#{scope}, max-age=31536000, immutable")
      |> send_resp(200, png)
    else
      _ -> send_resp(conn, :not_found, "")
    end
  end
end
