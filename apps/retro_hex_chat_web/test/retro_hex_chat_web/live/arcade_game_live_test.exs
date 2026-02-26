defmodule RetroHexChatWeb.ArcadeGameLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.Arcade
  alias RetroHexChat.Arcade.Queries
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :liveview

  setup do
    Application.put_env(:retro_hex_chat, :arcade_pending_timeout, :timer.seconds(60))
    Application.put_env(:retro_hex_chat, :arcade_lobby_warning_timeout, :timer.seconds(60))
    Application.put_env(:retro_hex_chat, :arcade_lobby_expiry_timeout, :timer.seconds(60))

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :arcade_pending_timeout)
      Application.delete_env(:retro_hex_chat, :arcade_lobby_warning_timeout)
      Application.delete_env(:retro_hex_chat, :arcade_lobby_expiry_timeout)
    end)

    n = System.unique_integer([:positive])
    creator = create_nick("agl#{n}")
    {:ok, creator: creator, nick: "agl#{n}"}
  end

  defp create_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp create_playing_session(creator_id, game_id \\ "doom_shareware") do
    {:ok, %{token: token}} = Arcade.create_session(creator_id)
    :ok = Arcade.join_session(token, creator_id)
    :ok = Arcade.select_game(token, creator_id, game_id)
    token
  end

  describe "mount" do
    test "guest without nickname is redirected", %{conn: conn} do
      assert {:error, {:live_redirect, _}} = live(conn, "/arcade/some-token/doom_shareware")
    end

    test "unregistered nick is redirected", %{conn: conn} do
      conn = chat_conn(conn, "ghost_arcade")
      assert {:error, {:live_redirect, _}} = live(conn, "/arcade/some-token/doom_shareware")
    end

    test "invalid token redirects to /chat", %{conn: conn, nick: nick} do
      conn = chat_conn(conn, nick)
      assert {:error, {:live_redirect, _}} = live(conn, "/arcade/nonexistent/doom_shareware")
    end

    test "non-creator is redirected", %{conn: conn, creator: creator} do
      other = create_nick("ago#{System.unique_integer([:positive])}")
      token = create_playing_session(creator.id)

      conn = chat_conn(conn, other.nickname)
      assert {:error, {:live_redirect, _}} = live(conn, "/arcade/#{token}/doom_shareware")
    end

    test "session not in playing state redirects", %{conn: conn, creator: creator, nick: nick} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)
      # Session is in "lobby", not "playing"

      conn = chat_conn(conn, nick)
      assert {:error, {:live_redirect, _}} = live(conn, "/arcade/#{token}/doom_shareware")
    end

    test "mismatched game_id redirects", %{conn: conn, creator: creator, nick: nick} do
      token = create_playing_session(creator.id, "doom_shareware")

      conn = chat_conn(conn, nick)
      # Session is playing doom_shareware, but URL says quake_shareware
      assert {:error, {:live_redirect, _}} = live(conn, "/arcade/#{token}/quake_shareware")
    end

    test "creator mounts successfully with correct game", %{
      conn: conn,
      creator: creator,
      nick: nick
    } do
      token = create_playing_session(creator.id, "doom_shareware")

      conn = chat_conn(conn, nick)
      {:ok, _view, html} = live(conn, "/arcade/#{token}/doom_shareware")

      assert html =~ "arcade-game"
      assert html =~ "arcade-game-iframe"
    end
  end

  describe "game_window_closing event" do
    test "finishes the game and marks session closed", %{
      conn: conn,
      creator: creator,
      nick: nick
    } do
      token = create_playing_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/arcade/#{token}/doom_shareware")

      render_click(view, "game_window_closing", %{})

      # Give GenServer time to stop
      Process.sleep(50)

      session = Queries.get_session_by_token(token)
      assert session.status == "finished"
      assert session.closed_reason == "game_over"
    end
  end

  describe "PubSub" do
    test "arcade_session_closed pushes close tab event", %{
      conn: conn,
      creator: creator,
      nick: nick
    } do
      token = create_playing_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/arcade/#{token}/doom_shareware")

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "arcade:#{token}",
        %{event: "arcade_session_closed", payload: %{reason: "user_closed"}}
      )

      assert_push_event(view, "arcade_close_tab", %{})
    end
  end
end
