defmodule RetroHexChatWeb.SessionController do
  @moduledoc """
  Receives POST from ConnectLive or ChannelListLive, stores chat credentials
  in the encrypted session cookie, and redirects to `/chat` with a clean URL.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Accounts.NicknameValidator

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"nickname" => nickname} = params) do
    with :ok <- NicknameValidator.validate(nickname),
         :ok <- verify_optional_token(params["auth_token"], nickname) do
      pre_identified = params["auth_token"] != nil && params["auth_token"] != ""

      conn
      |> put_session(:chat_nickname, nickname)
      |> put_session(:chat_pre_identified, pre_identified)
      |> put_session(:chat_timezone, params["timezone"] || "Etc/UTC")
      |> maybe_put_join_channel(params["join_channel"])
      |> redirect(to: ~p"/chat")
    else
      _ ->
        redirect(conn, to: ~p"/connect")
    end
  end

  def create(conn, _params) do
    redirect(conn, to: ~p"/connect")
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, params) do
    reason = params["reason"] || "disconnected"

    conn
    |> clear_session()
    |> redirect(to: ~p"/connect?reason=#{reason}")
  end

  @spec verify_optional_token(String.t() | nil, String.t()) :: :ok | :error
  defp verify_optional_token(nil, _nickname), do: :ok
  defp verify_optional_token("", _nickname), do: :ok

  defp verify_optional_token(token, nickname) do
    case Phoenix.Token.verify(RetroHexChatWeb.Endpoint, "nickserv_identify", token, max_age: 30) do
      {:ok, ^nickname} -> :ok
      _ -> :error
    end
  end

  @spec maybe_put_join_channel(Plug.Conn.t(), String.t() | nil) :: Plug.Conn.t()
  defp maybe_put_join_channel(conn, nil), do: conn
  defp maybe_put_join_channel(conn, ""), do: conn
  defp maybe_put_join_channel(conn, channel), do: put_session(conn, :chat_join_channel, channel)
end
