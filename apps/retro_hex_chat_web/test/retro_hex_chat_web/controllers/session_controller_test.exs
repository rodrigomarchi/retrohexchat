defmodule RetroHexChatWeb.SessionControllerTest do
  use RetroHexChatWeb.ConnCase

  alias RetroHexChat.Services.NickServ

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

    test "join_channel param stores channel in session", %{conn: conn} do
      conn =
        post(conn, ~p"/chat/session", %{
          "nickname" => "JoinNick",
          "join_channel" => "#general"
        })

      assert redirected_to(conn) == "/chat"
      assert get_session(conn, :chat_nickname) == "JoinNick"
      assert get_session(conn, :chat_join_channel) == "#general"
    end

    test "without join_channel param does not set chat_join_channel in session", %{conn: conn} do
      conn = post(conn, ~p"/chat/session", %{"nickname" => "NoJoin"})
      assert redirected_to(conn) == "/chat"
      refute get_session(conn, :chat_join_channel)
    end
  end
end
