defmodule RetroHexChatWeb.RedirectController do
  @moduledoc "Redirects legacy /v2/* paths to root equivalents."
  use RetroHexChatWeb, :controller

  @spec legacy_connect(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def legacy_connect(conn, params) do
    redirect(conn, to: build_path("/connect", params))
  end

  @spec legacy_chat(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def legacy_chat(conn, params) do
    redirect(conn, to: build_path("/chat", params))
  end

  @spec legacy_session_clear(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def legacy_session_clear(conn, params) do
    redirect(conn, to: build_path("/chat/session/clear", params))
  end

  defp build_path(base, params) do
    query = Map.drop(params, ["_format"])

    if query == %{} do
      base
    else
      base <> "?" <> URI.encode_query(query)
    end
  end
end
