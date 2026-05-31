defmodule RetroHexChatWeb.V2.SessionController do
  @moduledoc """
  Session controller — handles login/logout and redirects to chat routes.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Accounts.NicknameValidator

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"nickname" => nickname} = params) do
    with :ok <- NicknameValidator.validate(nickname),
         :ok <- verify_optional_token(params["auth_token"], nickname) do
      pre_identified = params["auth_token"] != nil && params["auth_token"] != ""
      previous_nickname = get_session(conn, :chat_nickname)

      redirect_path = join_channel_redirect(params["join_channel"])

      conn
      |> maybe_put_nick_change_flash(previous_nickname, nickname)
      |> put_session(:chat_nickname, nickname)
      |> put_session(:chat_pre_identified, pre_identified)
      |> put_session(:chat_timezone, params["timezone"] || "Etc/UTC")
      |> delete_session(:chat_join_channel)
      |> redirect(to: redirect_path)
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
    locale = get_session(conn, :locale)

    conn
    |> clear_session()
    |> maybe_restore_locale(locale)
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

  @spec join_channel_redirect(String.t() | nil) :: String.t()
  defp join_channel_redirect(nil), do: ~p"/chat"
  defp join_channel_redirect(""), do: ~p"/chat"
  defp join_channel_redirect(channel), do: ~p"/chat?join=#{channel}"

  defp maybe_put_nick_change_flash(conn, old_nickname, new_nickname)
       when is_binary(old_nickname) and old_nickname != "" and old_nickname != new_nickname do
    put_flash(conn, :nick_changed_from, old_nickname)
  end

  defp maybe_put_nick_change_flash(conn, _old_nickname, _new_nickname), do: conn

  defp maybe_restore_locale(conn, locale) when is_binary(locale) and locale != "" do
    put_session(conn, :locale, locale)
  end

  defp maybe_restore_locale(conn, _locale), do: conn
end
