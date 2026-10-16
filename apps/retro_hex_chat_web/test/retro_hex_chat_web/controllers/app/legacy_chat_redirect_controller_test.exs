defmodule RetroHexChatWeb.App.LegacyChatRedirectControllerTest do
  use RetroHexChatWeb.ConnCase, async: true

  # Every link that still carries the chat's old address — bookmarks, old share
  # cards, notifications, installed apps — lands where the same thing lives now,
  # and says so permanently.
  for {from, to} <- [
        {"/chat", "/"},
        {"/chat?join=%23retro", "/c/retro"},
        {"/chat?conversation=%23retro", "/c/retro"},
        {"/chat?conversation=somebody", "/"},
        {"/chat?arcade=doom_shareware", "/?arcade=doom_shareware"},
        {"/chat?signup=games&return_to=%2Fplay%2Fhex_pong",
         "/connect?signup=games&return_to=%2Fplay%2Fhex_pong"}
      ] do
    test "#{from} moves permanently to #{to}", %{conn: conn} do
      conn = get(conn, unquote(from))

      assert conn.status == 301
      assert redirected_to(conn, 301) == unquote(to)
    end
  end

  test "a way back that is not ours is dropped on the way", %{conn: conn} do
    conn = get(conn, "/chat?signup=games&return_to=%2F%2Fevil.example")

    assert redirected_to(conn, 301) == "/connect?signup=games&return_to=%2F"
  end

  # A 301 is kept by the browser for good, so it never carries a language:
  # the unprefixed address sends each reader on to their own.
  test "a reader with a language is sent to the unprefixed address", %{conn: conn} do
    conn = conn |> init_test_session(%{locale: "pt_BR"}) |> get("/chat?join=%23retro")

    assert redirected_to(conn, 301) == "/c/retro"
  end

  test "a malformed query is the home, never an error", %{conn: conn} do
    assert redirected_to(get(conn, "/chat?signup[a]=b"), 301) == "/"
    assert redirected_to(get(build_conn(), "/chat?join[a]=b"), 301) == "/"
  end
end
