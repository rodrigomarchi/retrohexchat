defmodule RetroHexChatWeb.GameSessionLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.Games.{Queries, SessionServer, Supervisor}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :liveview

  setup do
    Application.put_env(:retro_hex_chat, :game_pending_timeout, 30_000)
    Application.put_env(:retro_hex_chat, :game_lobby_warning_timeout, 30_000)
    Application.put_env(:retro_hex_chat, :game_lobby_expiry_timeout, 60_000)
    Application.put_env(:retro_hex_chat, :game_select_timeout, 30_000)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :game_pending_timeout)
      Application.delete_env(:retro_hex_chat, :game_lobby_warning_timeout)
      Application.delete_env(:retro_hex_chat, :game_lobby_expiry_timeout)
      Application.delete_env(:retro_hex_chat, :game_select_timeout)
    end)
  end

  defp create_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp create_game_session(creator_id, peer_id) do
    token = "game-lv-#{uid()}"

    {:ok, session} =
      Queries.insert_session(%{
        token: token,
        creator_id: creator_id,
        peer_id: peer_id,
        status: "pending"
      })

    {:ok, _pid} = Supervisor.start_child(session.token)
    session
  end

  defp stop_server(token) do
    case RetroHexChat.Games.Registry.lookup(token) do
      {:ok, pid} ->
        GenServer.stop(pid, :normal)
        Process.sleep(10)

      {:error, :not_found} ->
        :ok
    end
  end

  describe "mount/auth" do
    test "guest is redirected to /connect", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/connect"}}} = live(conn, "/game/some-token")
    end

    test "unregistered nick is redirected", %{conn: conn} do
      conn = chat_conn(conn, "ghost_gamer")
      assert {:error, {:live_redirect, _}} = live(conn, "/game/some-token")
    end

    test "invalid token redirects", %{conn: conn} do
      _alice = create_nick("gm_lv_a1")
      conn = chat_conn(conn, "gm_lv_a1")
      assert {:error, {:live_redirect, _}} = live(conn, "/game/nonexistent-token")
    end

    test "unauthorized user is redirected", %{conn: conn} do
      alice = create_nick("gm_lv_a2")
      bob = create_nick("gm_lv_b2")
      _charlie = create_nick("gm_lv_c2")

      session = create_game_session(alice.id, bob.id)
      conn = chat_conn(conn, "gm_lv_c2")

      assert {:error, {:live_redirect, _}} = live(conn, "/game/#{session.token}")
      stop_server(session.token)
    end

    test "creator mounts successfully", %{conn: conn} do
      alice = create_nick("gm_lv_a3")
      bob = create_nick("gm_lv_b3")

      session = create_game_session(alice.id, bob.id)
      conn = chat_conn(conn, "gm_lv_a3")

      {:ok, _view, html} = live(conn, "/game/#{session.token}")
      assert html =~ "Game Session"
      assert html =~ "gm_lv_a3"
      stop_server(session.token)
    end

    test "peer mounts successfully", %{conn: conn} do
      alice = create_nick("gm_lv_a4")
      bob = create_nick("gm_lv_b4")

      session = create_game_session(alice.id, bob.id)
      conn = chat_conn(conn, "gm_lv_b4")

      {:ok, _view, html} = live(conn, "/game/#{session.token}")
      assert html =~ "Game Session"
      assert html =~ "gm_lv_b4"
      stop_server(session.token)
    end

    test "terminal session shows expired page", %{conn: conn} do
      alice = create_nick("gm_lv_a5")
      bob = create_nick("gm_lv_b5")

      session = create_game_session(alice.id, bob.id)
      SessionServer.close(session.token, alice.id, "user_closed")
      Process.sleep(50)

      conn = chat_conn(conn, "gm_lv_a5")
      {:ok, _view, html} = live(conn, "/game/#{session.token}")
      assert html =~ "Session Unavailable"
    end
  end

  describe "lobby" do
    test "shows game picker when both join", %{conn: conn} do
      alice = create_nick("gm_lv_a6")
      bob = create_nick("gm_lv_b6")

      session = create_game_session(alice.id, bob.id)

      # Both join to transition to lobby
      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)
      Process.sleep(50)

      conn = chat_conn(conn, "gm_lv_a6")
      {:ok, _view, html} = live(conn, "/game/#{session.token}")

      assert html =~ "Choose a game"
      assert html =~ "Hex Pong"
      assert html =~ "Light Trails"
      assert html =~ "Pixel Tanks"
      assert html =~ "Star Duel"
      assert html =~ "Block Breakers"
      stop_server(session.token)
    end

    test "game selection shows consent banner", %{conn: conn} do
      alice = create_nick("gm_lv_a7")
      bob = create_nick("gm_lv_b7")

      session = create_game_session(alice.id, bob.id)
      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)
      Process.sleep(50)

      conn = chat_conn(conn, "gm_lv_b7")
      {:ok, view, _html} = live(conn, "/game/#{session.token}")

      # Alice selects a game
      SessionServer.select_game(session.token, alice.id, "gm_lv_a7", "hex_pong")
      Process.sleep(50)

      html = render(view)
      assert html =~ "gm_lv_a7"
      assert html =~ "hex_pong"
      assert html =~ "Accept"
      assert html =~ "Decline"
      stop_server(session.token)
    end

    test "select_game event works from UI", %{conn: conn} do
      alice = create_nick("gm_lv_a8")
      bob = create_nick("gm_lv_b8")

      session = create_game_session(alice.id, bob.id)
      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)
      Process.sleep(50)

      conn = chat_conn(conn, "gm_lv_a8")
      {:ok, view, _html} = live(conn, "/game/#{session.token}")

      render_click(view, "select_game", %{"game_id" => "light_trails"})
      Process.sleep(50)

      html = render(view)
      # Requester sees waiting indicator
      assert html =~ "Waiting for response"
      stop_server(session.token)
    end

    test "lobby chat works", %{conn: conn} do
      alice = create_nick("gm_lv_a9")
      bob = create_nick("gm_lv_b9")

      session = create_game_session(alice.id, bob.id)
      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)
      Process.sleep(50)

      conn = chat_conn(conn, "gm_lv_a9")
      {:ok, view, _html} = live(conn, "/game/#{session.token}")

      render_submit(view, "send_lobby_message", %{"content" => "hello!"})
      Process.sleep(50)

      html = render(view)
      assert html =~ "hello!"
      stop_server(session.token)
    end
  end

  describe "session close" do
    test "close_session pushes close event", %{conn: conn} do
      alice = create_nick("gm_lv_c1")
      bob = create_nick("gm_lv_c2b")

      session = create_game_session(alice.id, bob.id)
      conn = chat_conn(conn, "gm_lv_c1")

      {:ok, view, _html} = live(conn, "/game/#{session.token}")
      render_click(view, "close_session", %{})

      assert_push_event(view, "game_close_tab", %{})
    end
  end
end
