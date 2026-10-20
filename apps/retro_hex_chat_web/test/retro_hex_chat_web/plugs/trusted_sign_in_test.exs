defmodule RetroHexChatWeb.Plugs.TrustedSignInTest do
  use RetroHexChatWeb.ConnCase, async: false

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.TrustedDeviceCookie

  @moduletag :integration

  defp terminal(prefix, auto_login) do
    nick = "#{prefix}#{System.unique_integer([:positive])}"
    NickServ.register(nick, "pass123")
    {:ok, %{device: device, cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)
    :ok = TrustedDevices.set_auto_login(device.id, nick, auto_login, nick)
    %{nick: nick, device: device, cookie: cookie}
  end

  defp with_terminal(conn, %{cookie: cookie}),
    do: put_req_cookie(conn, TrustedDeviceCookie.name(), cookie)

  test "a terminal set to Auto-login opens the chat signed in, on the first request", %{
    conn: conn
  } do
    %{nick: nick, device: device} = terminal = terminal("AutoIn", true)

    conn = conn |> with_terminal(terminal) |> get(~p"/")

    assert html_response(conn, 200) =~ ~s(data-member="true")
    assert get_session(conn, :chat_nickname) == nick
    assert get_session(conn, :chat_pre_identified) == true
    assert is_binary(get_session(conn, :chat_session_id))
    assert get_session(conn, :trusted_device_id) == device.id
  end

  test "any address of the desktop signs in, and stays where it was", %{conn: conn} do
    %{nick: nick} = terminal = terminal("AutoAny", true)

    conn = conn |> with_terminal(terminal) |> get(~p"/faq")

    assert html_response(conn, 200)
    assert get_session(conn, :chat_nickname) == nick
  end

  test "the sign-in window's address goes where signing in would have", %{conn: conn} do
    terminal = terminal("AutoWin", true)

    assert conn |> with_terminal(terminal) |> get(~p"/connect") |> redirected_to() == "/"

    assert conn
           |> with_terminal(terminal)
           |> get(~p"/connect?signup=calls&return_to=/call/abc123")
           |> redirected_to() == "/call/abc123"

    assert conn
           |> with_terminal(terminal)
           |> get(~p"/connect?return_to=https://evil.example")
           |> redirected_to() == "/"
  end

  test "a remembered nickname without Auto-login waits to be chosen", %{conn: conn} do
    terminal = terminal("AutoOff", false)

    conn = conn |> with_terminal(terminal) |> get(~p"/")

    assert html_response(conn, 200) =~ ~s(data-member="false")
    refute get_session(conn, :chat_nickname)
  end

  test "an ended session is not signed back in until the browser closes", %{conn: conn} do
    terminal = terminal("AutoOut", true)

    for reason <- ["logout", "ended", "expired"] do
      conn =
        conn
        |> with_terminal(terminal)
        |> get(~p"/")
        |> get(~p"/chat/session/clear?reason=#{reason}")

      assert get_session(conn, :trusted_sign_in_paused) == true

      after_clear = get(conn, redirected_to(conn))
      assert html_response(after_clear, 200)
      refute get_session(after_clear, :chat_nickname)

      again = get(after_clear, ~p"/")
      assert html_response(again, 200) =~ ~s(data-member="false")
    end
  end

  test "signing in from the window lifts the pause", %{conn: conn} do
    %{nick: nick} = terminal = terminal("AutoBack", true)

    conn =
      conn
      |> with_terminal(terminal)
      |> get(~p"/chat/session/clear?reason=logout")
      |> post(~p"/chat/session", %{"nickname" => nick, "trusted_device_login" => "true"})

    assert get_session(conn, :chat_nickname) == nick
    refute get_session(conn, :trusted_sign_in_paused)
  end

  test "a banned nickname is not signed in, nor asked about again", %{conn: conn} do
    %{nick: nick} = terminal = terminal("AutoBan", true)
    {:ok, _msg} = ServerBans.ban(nick, "admin", "testing", nil)

    conn = conn |> with_terminal(terminal) |> get(~p"/")

    refute get_session(conn, :chat_nickname)
    assert get_session(conn, :trusted_sign_in_paused) == true
  end

  test "a browser already signed in keeps its nickname", %{conn: conn} do
    terminal = terminal("AutoKeep", true)

    conn =
      conn
      |> init_test_session(%{chat_nickname: "SomebodyElse"})
      |> with_terminal(terminal)
      |> get(~p"/")

    assert get_session(conn, :chat_nickname) == "SomebodyElse"
  end

  test "a revoked terminal signs nobody in", %{conn: conn} do
    %{nick: nick, device: device} = terminal = terminal("AutoRev", true)
    :ok = TrustedDevices.revoke_device_for_nick(nick, device.id, nick)

    conn = conn |> with_terminal(terminal) |> get(~p"/")

    refute get_session(conn, :chat_nickname)
  end
end
