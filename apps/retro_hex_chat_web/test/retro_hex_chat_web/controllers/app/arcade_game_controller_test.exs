defmodule RetroHexChatWeb.App.ArcadeGameControllerTest do
  @moduledoc """
  The arcade's own address — the name we can give out for a bundle that lives
  on somebody else's host.
  """
  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChat.Arcade
  alias RetroHexChat.Games.Catalog
  alias RetroHexChatWeb.App.Paths

  # The arcade asks what the chat's arcade asks: a signed-in, identified
  # nickname. These tests are about where the game is, so they sign in.
  setup %{conn: conn} do
    %{conn: init_test_session(conn, chat_nickname: "Player1", chat_pre_identified: true)}
  end

  test "an arcade game redirects to wherever its bundle actually lives", %{conn: conn} do
    [game | _rest] = Arcade.list_games()

    conn = get(conn, "/play/arcade/#{game.id}")

    assert redirected_to(conn, 302) == Arcade.game_url(game)
  end

  # A ScummVM game carries its auto-start in the fragment, which a redirect has
  # to leave intact or the game opens on a menu instead of the story.
  test "a ScummVM game keeps the fragment that starts it", %{conn: conn} do
    scummvm = Enum.find(Arcade.list_games(), &(&1.engine == :scummvm))

    if scummvm do
      conn = get(conn, "/play/arcade/#{scummvm.id}")
      target = redirected_to(conn, 302)

      assert target == Arcade.game_url(scummvm)
      assert target =~ "#"
    end
  end

  test "an address that names no game reads like any other dead link", %{conn: conn} do
    conn = get(conn, "/play/arcade/no_such_game")

    assert redirected_to(conn, 302) == "/chat"
  end

  # `/play/:game/:token` has the same shape, so the arcade's route has to be
  # the one that matches: `arcade` is a reserved word in this namespace, not a
  # game id somebody could pick.
  test "the arcade route wins over the match route it looks like", %{conn: conn} do
    [game | _rest] = Arcade.list_games()

    conn = get(conn, "/play/arcade/#{game.id}")

    assert redirected_to(conn, 302) == Arcade.game_url(game)
    refute Catalog.valid_game_id?("arcade")
  end

  describe "who may open it" do
    test "a visitor lands in the chat, asked to sign in for games and brought back to the game" do
      [game | _rest] = Arcade.list_games()

      conn = get(build_conn(), "/play/arcade/#{game.id}")

      assert redirected_to(conn, 302) ==
               Paths.visitor_sign_in_path(:games, Paths.chat_arcade_path(game.id))
    end

    test "a session that never proved its nickname is asked the same" do
      [game | _rest] = Arcade.list_games()

      conn =
        build_conn()
        |> init_test_session(chat_nickname: "Unproven1")
        |> get("/play/arcade/#{game.id}")

      assert redirected_to(conn, 302) =~ "signup=games"
    end
  end
end
