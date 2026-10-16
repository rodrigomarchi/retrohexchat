defmodule RetroHexChatWeb.App.LegacyChatRedirectController do
  @moduledoc """
  `/chat`, the chat's address before it became the desktop's home, and every
  link that still carries it — bookmarks, notifications, old share cards,
  installed apps.

  Each answers with a permanent redirect to where the same thing lives: the
  home, a channel's own `/c/` address, the sign-in window or the arcade. The
  target is always the unprefixed address — a browser keeps a 301 for good, so
  it must not carry the language of whoever followed it first; the unprefixed
  address sends each reader on to their own (`Plugs.PutLocale`). A private
  conversation has no address, so a link to one opens the home.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChatWeb.App.ReturnTo
  alias RetroHexChatWeb.Site.Address

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: destination(params))
  end

  defp destination(%{"join" => "#" <> _ = channel}), do: Address.channel_path(channel)
  defp destination(%{"conversation" => "#" <> _ = channel}), do: Address.channel_path(channel)

  defp destination(%{"signup" => feature} = params) when is_binary(feature) do
    "/connect?" <>
      URI.encode_query(signup: feature, return_to: ReturnTo.sanitize(params["return_to"]))
  end

  defp destination(%{"arcade" => game_id}) when is_binary(game_id),
    do: "/?" <> URI.encode_query(arcade: game_id)

  defp destination(_params), do: "/"
end
