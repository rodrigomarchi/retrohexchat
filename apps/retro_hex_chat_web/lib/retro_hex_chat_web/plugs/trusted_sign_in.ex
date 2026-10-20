defmodule RetroHexChatWeb.Plugs.TrustedSignIn do
  @moduledoc """
  Signs a trusted terminal in by itself, before anything is rendered.

  When the browser has no chat session, its terminal (verified by
  `Plugs.PutTrustedDevice`) has a nickname set to Auto-login, and no session
  ended on this browser since it opened (`App.SessionSignIn.pause/1`), the
  nickname goes into the session on this very request: the page answers as the
  member, with no sign-in window, form or reload in between.

  On the sign-in window's own address there is nothing left to sign in to, so
  the browser goes where signing in would have taken it.
  """
  @behaviour Plug

  import Plug.Conn

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.ReturnTo
  alias RetroHexChatWeb.App.SessionSignIn

  @impl Plug
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @impl Plug
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(%Plug.Conn{method: "GET", private: %{trusted_device: device}} = conn, _opts) do
    with nil <- get_session(conn, :chat_nickname),
         false <- SessionSignIn.paused?(conn),
         {:ok, nickname} <- TrustedDevices.auto_sign_in(device) do
      sign_in(conn, nickname, device.id)
    else
      _ -> conn
    end
  end

  def call(conn, _opts), do: conn

  # A banned nickname is not signed in, and not asked about again on every page
  # of this browser session.
  defp sign_in(conn, nickname, device_id) do
    if ServerBans.banned?(nickname) do
      SessionSignIn.pause(conn)
    else
      conn
      |> SessionSignIn.put(nickname, device_id)
      |> leave_sign_in_window()
    end
  end

  defp leave_sign_in_window(%Plug.Conn{path_info: path_info} = conn) do
    if List.last(path_info) == "connect" do
      conn
      |> Phoenix.Controller.redirect(to: destination(fetch_query_params(conn).query_params))
      |> halt()
    else
      conn
    end
  end

  defp destination(%{"return_to" => return_to}) when is_binary(return_to) and return_to != "",
    do: return_to |> ReturnTo.sanitize() |> Paths.localized()

  defp destination(_params), do: Paths.chat_path()
end
