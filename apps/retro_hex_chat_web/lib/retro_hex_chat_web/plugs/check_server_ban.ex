defmodule RetroHexChatWeb.Plugs.CheckServerBan do
  @moduledoc "Plug that blocks banned users from creating chat sessions."
  import Plug.Conn

  alias RetroHexChat.Admin.BanCache

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    nickname = conn.params["nickname"] || get_session(conn, :nickname)

    if nickname && BanCache.banned?(nickname) do
      conn
      |> Phoenix.Controller.redirect(to: "/connect?reason=banned")
      |> halt()
    else
      conn
    end
  end
end
