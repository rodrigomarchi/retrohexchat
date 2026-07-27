defmodule RetroHexChatWeb.App.TrustedDeviceCookie do
  @moduledoc """
  HTTP-only trusted-device cookie helpers.

  The database stores only selector + token hash. The browser stores the opaque
  selector.secret pair in this cookie so LiveView code never needs direct access
  to the long-lived credential.
  """

  import Plug.Conn

  @cookie_name "_rhc_trusted_device"

  @spec name() :: String.t()
  def name, do: @cookie_name

  @spec fetch(Plug.Conn.t()) :: String.t() | nil
  def fetch(conn) do
    conn = fetch_cookies(conn)
    conn.req_cookies[@cookie_name]
  end

  @spec put(Plug.Conn.t(), String.t(), pos_integer()) :: Plug.Conn.t()
  def put(conn, value, max_age) do
    put_resp_cookie(conn, @cookie_name, value, cookie_opts(conn, max_age))
  end

  @spec delete(Plug.Conn.t()) :: Plug.Conn.t()
  def delete(conn) do
    delete_resp_cookie(conn, @cookie_name, cookie_opts(conn, 0))
  end

  defp cookie_opts(conn, max_age) do
    [
      max_age: max_age,
      http_only: true,
      same_site: "Lax",
      secure: conn.scheme == :https
    ]
  end
end
