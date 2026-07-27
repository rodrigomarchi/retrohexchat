defmodule RetroHexChatWeb.Plugs.PutTrustedDevice do
  @moduledoc """
  Validates the trusted-device cookie and mirrors the trusted device id into the
  encrypted Phoenix session for LiveViews.
  """

  import Plug.Conn

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChatWeb.App.TrustedDeviceCookie

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    conn = fetch_cookies(conn)

    case TrustedDeviceCookie.fetch(conn) do
      nil ->
        delete_session(conn, :trusted_device_id)

      cookie ->
        case TrustedDevices.verify_cookie(cookie) do
          {:ok, device} ->
            put_session(conn, :trusted_device_id, device.id)

          {:error, _reason} ->
            conn
            |> delete_session(:trusted_device_id)
            |> TrustedDeviceCookie.delete()
        end
    end
  end
end
