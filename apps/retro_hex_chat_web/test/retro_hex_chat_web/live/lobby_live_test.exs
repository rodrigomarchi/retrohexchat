defmodule RetroHexChatWeb.App.LobbyLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Lobby.{Queries, Registry, SessionServer, Supervisor}
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :liveview

  setup do
    creator = create_registered_nick("lobc#{uid()}")
    peer = create_registered_nick("lobp#{uid()}")
    token = "lvlobby-#{System.unique_integer([:positive])}"

    {:ok, session} =
      Queries.insert_session(%{
        token: token,
        creator_id: creator.id,
        peer_id: peer.id,
        status: "pending"
      })

    {:ok, _pid} = Supervisor.start_child(token)

    on_exit(fn ->
      case Registry.lookup(token) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        _ -> :ok
      end
    end)

    {:ok, session: session, token: token, creator: creator, peer: peer}
  end

  defp connect_both(conn, token, creator, peer) do
    {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/lobby/#{token}")
    SessionServer.join(token, peer.id)
    :ok = SessionServer.transition(token, :connected)
    Process.sleep(50)
    view
  end

  describe "mount" do
    test "renders the lobby shell as a desktop with a taskbar", %{
      conn: conn,
      token: token,
      creator: creator
    } do
      {:ok, _view, html} = live(chat_conn(conn, creator.nickname), "/lobby/#{token}")

      assert html =~ "Universal Lobby"
      assert html =~ ~s(data-testid="lobby-desktop")
    end

    test "call features in the Start menu are disabled until the connection is established",
         %{conn: conn, token: token, creator: creator} do
      {:ok, _view, html} = live(chat_conn(conn, creator.nickname), "/lobby/#{token}")

      assert html =~ ~s(data-testid="lobby-menu-video")
      # Start-call items carry the disabled attribute before "connected".
      assert html =~ "disabled"
    end
  end

  describe "connected lobby" do
    test "the game picker lists available games", %{
      conn: conn,
      token: token,
      creator: creator,
      peer: peer
    } do
      view = connect_both(conn, token, creator, peer)

      # The game window content renders as soon as the lobby is connected — no
      # panel toggle needed; the window manager owns visibility on the client.
      html = render(view)

      assert html =~ ~s(data-testid="lobby-game-panel")
      assert html =~ "Hex Pong"
    end

    test "proposing a game shows a waiting state for the proposer and lets the peer accept",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      {:ok, creator_view, _} = live(chat_conn(conn, creator.nickname), "/lobby/#{token}")
      {:ok, peer_view, _} = live(chat_conn(conn, peer.nickname), "/lobby/#{token}")

      SessionServer.join(token, creator.id)
      SessionServer.join(token, peer.id)
      :ok = SessionServer.transition(token, :connected)
      Process.sleep(50)

      render_click(creator_view, "propose_game", %{"game_id" => "hex_pong"})
      Process.sleep(50)

      assert render(creator_view) =~ "Waiting for"
      assert render(peer_view) =~ ~s(data-testid="lobby-game-consent")

      render_click(peer_view, "respond_game", %{"accepted" => "true"})
      Process.sleep(50)

      assert render(creator_view) =~ "Game in progress"
      assert render(peer_view) =~ "Game in progress"
    end

    test "a chat message is delivered to both peers", %{
      conn: conn,
      token: token,
      creator: creator,
      peer: peer
    } do
      {:ok, creator_view, _} = live(chat_conn(conn, creator.nickname), "/lobby/#{token}")
      {:ok, peer_view, _} = live(chat_conn(conn, peer.nickname), "/lobby/#{token}")

      SessionServer.join(token, creator.id)
      SessionServer.join(token, peer.id)
      :ok = SessionServer.transition(token, :connected)
      Process.sleep(50)

      render_submit(creator_view, "send_message", %{"content" => "hi there"})
      Process.sleep(50)

      assert render(peer_view) =~ "hi there"
    end

    test "starting a call shows media controls and the live network panel on stats",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      render_hook(view, "lobby_media_call_started", %{"type" => "video"})
      html = render(view)
      assert html =~ "End call"
      assert html =~ ~s(data-testid="lobby-media-panel")

      render_hook(view, "lobby_media_stats", %{
        "level" => "good",
        "mos" => 4.2,
        "rtt_ms" => 30,
        "jitter_ms" => 2,
        "loss_pct" => 0
      })

      assert render(view) =~ ~s(data-testid="lobby-network-panel")
    end

    test "ending a call keeps the lobby connected for more features",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      render_hook(view, "lobby_media_call_started", %{"type" => "audio"})
      render_hook(view, "lobby_media_call_ended", %{})
      html = render(view)

      # Features are usable again — the connection did not close.
      refute html =~ ~s(data-testid="lobby-ended")
      assert html =~ ~s(data-testid="lobby-menu-video")
    end
  end

  defp create_registered_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nick
  end
end
