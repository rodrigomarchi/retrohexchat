defmodule RetroHexChatWeb.App.SessionController do
  @moduledoc """
  Session controller — handles login/logout and redirects to chat routes.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.App.TrustedDeviceCookie

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"nickname" => nickname} = params) do
    with :ok <- NicknameValidator.validate(nickname),
         {:ok, auth} <- verify_identity_proof(conn, params, nickname),
         {:ok, conn, trusted_device_id} <- maybe_remember_device(conn, params, nickname, auth) do
      previous_nickname = get_session(conn, :chat_nickname)
      existing_trusted_device_id = get_session(conn, :trusted_device_id)
      redirect_path = join_channel_redirect(params["join_channel"])

      conn
      |> maybe_put_nick_change_flash(previous_nickname, nickname)
      |> put_session(:chat_nickname, nickname)
      |> put_session(:chat_pre_identified, auth.pre_identified)
      |> put_session(:chat_timezone, params["timezone"] || "Etc/UTC")
      |> maybe_put_trusted_device_session(
        trusted_device_id || auth[:trusted_device_id] || existing_trusted_device_id
      )
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
    |> maybe_delete_trusted_cookie(params)
    |> redirect(to: ~p"/connect?reason=#{reason}")
  end

  @spec verify_identity_proof(Plug.Conn.t(), map(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  defp verify_identity_proof(_conn, %{"auth_token" => token}, nickname)
       when is_binary(token) and token != "" do
    case Phoenix.Token.verify(RetroHexChatWeb.Endpoint, "nickserv_identify", token, max_age: 30) do
      {:ok, ^nickname} -> {:ok, %{pre_identified: true, source: :short_token}}
      _ -> {:error, :invalid_auth_token}
    end
  end

  defp verify_identity_proof(conn, params, nickname) do
    if truthy?(params["trusted_device_login"]) do
      case TrustedDeviceCookie.fetch(conn) |> TrustedDevices.authorize_cookie(nickname) do
        {:ok, %{device: device}} ->
          {:ok,
           %{
             pre_identified: true,
             source: :trusted_device,
             trusted_device_id: device.id
           }}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, %{pre_identified: false, source: :plain}}
    end
  end

  defp maybe_remember_device(conn, params, nickname, %{source: :short_token})
       when is_map(params) do
    if truthy?(params["remember_device"]) do
      opts = [
        client_info: SessionHelpers.parse_client_info(params),
        label: params["device_label"],
        user_agent_hash:
          TrustedDevices.hash_fingerprint(get_req_header(conn, "user-agent") |> List.first()),
        ip_hash: TrustedDevices.hash_fingerprint(remote_ip(conn)),
        actor_nickname: nickname
      ]

      cookie = TrustedDeviceCookie.fetch(conn)

      case TrustedDevices.remember_nick(cookie, nickname, opts) do
        {:ok, %{device: device, cookie_value: value, max_age: max_age}} ->
          {:ok, TrustedDeviceCookie.put(conn, value, max_age), device.id}

        {:error, _reason} ->
          {:ok, conn, nil}
      end
    else
      {:ok, conn, nil}
    end
  end

  defp maybe_remember_device(conn, _params, _nickname, _auth), do: {:ok, conn, nil}

  defp maybe_put_trusted_device_session(conn, nil), do: delete_session(conn, :trusted_device_id)

  defp maybe_put_trusted_device_session(conn, device_id),
    do: put_session(conn, :trusted_device_id, device_id)

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

  defp maybe_delete_trusted_cookie(conn, params) do
    if truthy?(params["forget_device"]) do
      TrustedDeviceCookie.delete(conn)
    else
      conn
    end
  end

  defp truthy?(value), do: value in [true, "true", "on", "1", 1]

  defp remote_ip(%{remote_ip: remote_ip}) when is_tuple(remote_ip) do
    remote_ip
    |> :inet.ntoa()
    |> to_string()
  end
end
