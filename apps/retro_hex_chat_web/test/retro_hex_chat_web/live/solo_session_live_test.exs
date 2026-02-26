defmodule RetroHexChatWeb.SoloSessionLiveTest do
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
    creator = create_nick("ssl#{n}")
    {:ok, creator: creator, nick: "ssl#{n}"}
  end

  defp create_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp create_lobby_session(creator_id) do
    {:ok, %{token: token}} = Arcade.create_session(creator_id)
    :ok = Arcade.join_session(token, creator_id)
    token
  end

  describe "mount" do
    test "guest without nickname is redirected", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/connect"}}} = live(conn, "/solo/some-token")
    end

    test "unregistered nick is redirected", %{conn: conn} do
      conn = chat_conn(conn, "ghost_solo")
      assert {:error, {:live_redirect, _}} = live(conn, "/solo/some-token")
    end

    test "invalid token redirects", %{conn: conn, nick: nick} do
      conn = chat_conn(conn, nick)
      assert {:error, {:live_redirect, _}} = live(conn, "/solo/nonexistent-token")
    end

    test "non-creator is redirected", %{conn: conn, creator: creator} do
      other = create_nick("sso#{System.unique_integer([:positive])}")
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, other.nickname)
      assert {:error, {:live_redirect, _}} = live(conn, "/solo/#{token}")
    end

    test "creator mounts lobby successfully", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, _view, html} = live(conn, "/solo/#{token}")

      assert html =~ "Arcade"
      assert html =~ nick
      assert html =~ "Choose a game"
    end

    test "terminal session shows expired page", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)
      :ok = Arcade.close_session(token, creator.id, "user_closed")
      Process.sleep(50)

      conn = chat_conn(conn, nick)
      {:ok, _view, html} = live(conn, "/solo/#{token}")

      assert html =~ "Session Unavailable"
    end
  end

  describe "game preview" do
    test "preview_game shows game detail screen", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      html = render_click(view, "preview_game", %{"game_id" => "doom_shareware"})

      assert html =~ "DOOM"
      assert html =~ "Start Game"
      assert html =~ "Back"
    end

    test "back_to_grid clears preview", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      render_click(view, "preview_game", %{"game_id" => "doom_shareware"})
      html = render_click(view, "back_to_grid", %{})

      assert html =~ "Choose a game"
      refute html =~ "Start Game"
    end

    test "preview_game with invalid game_id is ignored", %{
      conn: conn,
      creator: creator,
      nick: nick
    } do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      html = render_click(view, "preview_game", %{"game_id" => "nonexistent"})

      # Should stay in the picker
      assert html =~ "Choose a game"
    end
  end

  describe "game selection and window flow" do
    test "select_game pushes open_game_window event", %{
      conn: conn,
      creator: creator,
      nick: nick
    } do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      render_click(view, "select_game", %{"game_id" => "doom_shareware"})

      assert_push_event(view, "open_game_window", %{url: url})
      assert url =~ "/arcade/#{token}/doom_shareware"
    end

    test "playing state shows game in progress", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      render_click(view, "select_game", %{"game_id" => "doom_shareware"})
      Process.sleep(50)

      html = render(view)
      assert html =~ "Game in progress"
      assert html =~ "DOOM"
    end

    test "game_window_closed finishes the game", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      render_click(view, "select_game", %{"game_id" => "doom_shareware"})
      Process.sleep(50)

      render_click(view, "game_window_closed", %{})
      Process.sleep(50)

      html = render(view)
      assert html =~ "Session completed"

      session = Queries.get_session_by_token(token)
      assert session.status == "finished"
    end

    test "game_window_blocked reverts to lobby", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      render_click(view, "select_game", %{"game_id" => "doom_shareware"})
      Process.sleep(50)

      html = render_click(view, "game_window_blocked", %{})

      # Should be back to lobby/picker state
      assert html =~ "Choose a game"

      # Session should be finished in DB (game was cancelled)
      Process.sleep(50)
      session = Queries.get_session_by_token(token)
      assert session.status == "finished"
    end
  end

  describe "session close" do
    test "close_session pushes close tab event", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      render_click(view, "close_session", %{})

      assert_push_event(view, "arcade_close_tab", %{})
    end

    test "close_session during playing state", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      render_click(view, "select_game", %{"game_id" => "doom_shareware"})
      Process.sleep(50)

      render_click(view, "close_session", %{})

      assert_push_event(view, "arcade_close_tab", %{})

      Process.sleep(50)
      session = Queries.get_session_by_token(token)
      assert session.status in ["closed", "finished"]
    end
  end

  describe "PubSub handlers" do
    test "finished broadcast shows duration", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      render_click(view, "select_game", %{"game_id" => "doom_shareware"})
      Process.sleep(50)

      # Simulate the finished broadcast (normally sent by GenServer)
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "arcade:#{token}",
        %{
          event: "arcade_status_changed",
          payload: %{status: "finished", reason: "game_over", duration_seconds: 125}
        }
      )

      Process.sleep(50)
      html = render(view)
      assert html =~ "Session completed"
      assert html =~ "2m 5s"
    end

    test "inactivity warning is displayed", %{conn: conn, creator: creator, nick: nick} do
      token = create_lobby_session(creator.id)

      conn = chat_conn(conn, nick)
      {:ok, view, _html} = live(conn, "/solo/#{token}")

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "arcade:#{token}",
        %{event: "arcade_inactivity_warning", payload: %{expires_in_seconds: 300}}
      )

      Process.sleep(50)
      html = render(view)
      assert html =~ "inactivity"
    end
  end
end
