defmodule RetroHexChatWeb.App.SessionSignIn do
  @moduledoc """
  What a signed-in browser session carries, written the same way by every way in.

  The connect window's POST (`App.SessionController`) and a trusted terminal
  that signs in by itself (`Plugs.TrustedSignIn`) both end here, so the chat
  never tells one sign-in from the other.

  A session that ends — logged out, ended by another screen, expired, banned —
  pauses signing in by itself for the rest of the browser session. Without it,
  Log out would sign straight back in, and a screen ended by the session limit
  would come back and end another.
  """

  import Plug.Conn

  @paused :trusted_sign_in_paused

  @doc """
  Puts `nickname` in the session, proved: by its password or by a terminal it
  trusted. A new `chat_session_id` names this sign-in.
  """
  @spec put(Plug.Conn.t(), String.t(), integer() | nil) :: Plug.Conn.t()
  def put(conn, nickname, trusted_device_id) do
    conn
    |> put_session(:chat_nickname, nickname)
    |> put_session(:chat_pre_identified, true)
    |> put_session(:chat_session_id, new_session_id())
    |> put_trusted_device(trusted_device_id)
    |> delete_session(:chat_join_channel)
    |> delete_session(@paused)
  end

  @doc "Keeps a trusted terminal from signing in by itself until the browser closes."
  @spec pause(Plug.Conn.t()) :: Plug.Conn.t()
  def pause(conn), do: put_session(conn, @paused, true)

  @spec paused?(Plug.Conn.t()) :: boolean()
  def paused?(conn), do: get_session(conn, @paused) == true

  # Names this browser sign-in, so an identification made inside the chat (`/ns identify`)
  # survives a reload of this session and of no other.
  @spec new_session_id() :: String.t()
  def new_session_id, do: Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

  defp put_trusted_device(conn, nil), do: delete_session(conn, :trusted_device_id)
  defp put_trusted_device(conn, device_id), do: put_session(conn, :trusted_device_id, device_id)
end
