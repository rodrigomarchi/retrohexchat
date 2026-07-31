defmodule RetroHexChatWeb.SessionControllerTest do
  use RetroHexChatWeb.ConnCase

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.TrustedDeviceCookie

  @moduletag :integration

  describe "create/2" do
    test "valid nickname stores session and redirects to /chat", %{conn: conn} do
      conn = post(conn, ~p"/chat/session", %{"nickname" => "ValidNick"})
      assert redirected_to(conn) == "/chat"
      assert get_session(conn, :chat_nickname) == "ValidNick"
      refute get_session(conn, :chat_pre_identified)
    end

    test "invalid nickname redirects to /", %{conn: conn} do
      conn = post(conn, ~p"/chat/session", %{"nickname" => " bad"})
      assert redirected_to(conn) == "/connect"
      refute get_session(conn, :chat_nickname)
    end

    test "empty nickname redirects to /", %{conn: conn} do
      conn = post(conn, ~p"/chat/session", %{"nickname" => ""})
      assert redirected_to(conn) == "/connect"
    end

    test "missing nickname param redirects to /", %{conn: conn} do
      conn = post(conn, ~p"/chat/session", %{})
      assert redirected_to(conn) == "/connect"
    end

    test "valid auth_token sets pre_identified to true", %{conn: conn} do
      NickServ.register("AuthNick", "pass123")
      token = Phoenix.Token.sign(RetroHexChatWeb.Endpoint, "nickserv_identify", "AuthNick")

      conn =
        post(conn, ~p"/chat/session", %{"nickname" => "AuthNick", "auth_token" => token})

      assert redirected_to(conn) == "/chat"
      assert get_session(conn, :chat_nickname) == "AuthNick"
      assert get_session(conn, :chat_pre_identified) == true
    end

    test "valid auth_token can remember the current device", %{conn: conn} do
      nick = "Remember#{uid()}"
      NickServ.register(nick, "pass123")
      token = Phoenix.Token.sign(RetroHexChatWeb.Endpoint, "nickserv_identify", nick)

      conn =
        post(conn, ~p"/chat/session", %{
          "nickname" => nick,
          "auth_token" => token,
          "remember_device" => "true",
          "device_label" => "Office terminal",
          "client_info" => Jason.encode!(%{"browser" => "Firefox 140", "os" => "macOS 15"})
        })

      assert redirected_to(conn) == "/chat"
      assert get_session(conn, :chat_pre_identified) == true
      assert device_id = get_session(conn, :trusted_device_id)

      assert [%{nickname: ^nick, label: "Office terminal"}] =
               TrustedDevices.remembered_nicks(device_id)

      assert conn.resp_cookies[TrustedDeviceCookie.name()].http_only
    end

    test "trusted device login sets pre_identified without a password token", %{conn: conn} do
      nick = "Quick#{uid()}"
      NickServ.register(nick, "pass123")
      {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, nick)

      conn =
        conn
        |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
        |> post(~p"/chat/session", %{
          "nickname" => nick,
          "trusted_device_login" => "true"
        })

      assert redirected_to(conn) == "/chat"
      assert get_session(conn, :chat_nickname) == nick
      assert get_session(conn, :chat_pre_identified) == true
      assert get_session(conn, :trusted_device_id)
    end

    test "trusted device login rejects an untrusted nick", %{conn: conn} do
      first = "TrustA#{uid()}"
      second = "TrustB#{uid()}"
      NickServ.register(first, "pass123")
      NickServ.register(second, "pass123")
      {:ok, %{cookie_value: cookie}} = TrustedDevices.remember_nick(nil, first)

      conn =
        conn
        |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
        |> post(~p"/chat/session", %{
          "nickname" => second,
          "trusted_device_login" => "true"
        })

      assert redirected_to(conn) == "/connect"
      refute get_session(conn, :chat_nickname)
    end

    test "invalid auth_token redirects to /", %{conn: conn} do
      conn =
        post(conn, ~p"/chat/session", %{
          "nickname" => "SomeNick",
          "auth_token" => "bad_token"
        })

      assert redirected_to(conn) == "/connect"
    end

    test "expired auth_token redirects to /", %{conn: conn} do
      # Sign a token with the correct salt but it should be verifiable
      # We can't easily expire it, so test with wrong nickname match
      token = Phoenix.Token.sign(RetroHexChatWeb.Endpoint, "nickserv_identify", "OtherNick")

      conn =
        post(conn, ~p"/chat/session", %{
          "nickname" => "SomeNick",
          "auth_token" => token
        })

      assert redirected_to(conn) == "/connect"
    end

    test "without auth_token but valid nick stores session without pre_identified", %{conn: conn} do
      conn = post(conn, ~p"/chat/session", %{"nickname" => "PlainNick"})
      assert redirected_to(conn) == "/chat"
      assert get_session(conn, :chat_nickname) == "PlainNick"
      refute get_session(conn, :chat_pre_identified)
    end

    test "nickname with special chars that fail validation redirects to /", %{conn: conn} do
      conn = post(conn, ~p"/chat/session", %{"nickname" => "!!invalid!!"})
      assert redirected_to(conn) == "/connect"
    end

    test "join_channel param redirects with query param instead of storing in session", %{
      conn: conn
    } do
      conn =
        post(conn, ~p"/chat/session", %{
          "nickname" => "JoinNick",
          "join_channel" => "#general"
        })

      assert redirected_to(conn) == "/chat?join=%23general"
      assert get_session(conn, :chat_nickname) == "JoinNick"
      refute get_session(conn, :chat_join_channel)
    end

    test "without join_channel param redirects to /chat without query param", %{conn: conn} do
      conn = post(conn, ~p"/chat/session", %{"nickname" => "NoJoin"})
      assert redirected_to(conn) == "/chat"
      refute get_session(conn, :chat_join_channel)
    end
  end

  describe "delete/2" do
    test "clears session and redirects to /connect with reason", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{chat_nickname: "Cleared", chat_pre_identified: true})
        |> get(~p"/chat/session/clear?reason=expired")

      assert redirected_to(conn) == "/connect?reason=expired"
      refute get_session(conn, :chat_nickname)
      refute get_session(conn, :chat_pre_identified)
    end

    test "defaults reason to disconnected", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{chat_nickname: "DefReason"})
        |> get(~p"/chat/session/clear")

      assert redirected_to(conn) == "/connect?reason=disconnected"
    end

    test "preserves locale while clearing chat session", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{chat_nickname: "LocaleNick", locale: "pt_BR"})
        |> get(~p"/chat/session/clear")

      assert redirected_to(conn) == "/connect?reason=disconnected"
      assert get_session(conn, :locale) == "pt_BR"
      refute get_session(conn, :chat_nickname)
    end

    test "preserves disconnecting session context while clearing chat session", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{chat_nickname: "OldNick"})
        |> get(~p"/chat/session/clear?reason=disconnected&disconnected_by_session_ref=winner-ref")

      assert redirected_to(conn) == "/connect?reason=disconnected"

      assert %{
               "session_ref" => "winner-ref",
               "nickname" => "OldNick",
               "recorded_at" => recorded_at
             } = get_session(conn, :last_disconnect_context)

      assert {:ok, _recorded_at, _offset} = DateTime.from_iso8601(recorded_at)
      refute get_session(conn, :chat_nickname)
    end

    test "forget_device clears the trusted device cookie", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{chat_nickname: "ForgetNick", trusted_device_id: 123})
        |> put_req_cookie(TrustedDeviceCookie.name(), "selector.secret")
        |> get(~p"/chat/session/clear?reason=disconnected&forget_device=true")

      assert redirected_to(conn) == "/connect?reason=disconnected"
      assert conn.resp_cookies[TrustedDeviceCookie.name()].max_age == 0
      refute get_session(conn, :trusted_device_id)
    end
  end
end
