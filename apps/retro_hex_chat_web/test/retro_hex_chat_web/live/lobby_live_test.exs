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

      assert html =~ ~s(data-testid="lobby-desktop")
      # The status home is the pinned Statistics window (no top status bar).
      assert html =~ "Statistics"
      assert html =~ ~s(data-testid="lobby-window-conn")
    end

    test "the desktop carries a Win98 shortcut for each feature", %{
      conn: conn,
      token: token,
      creator: creator
    } do
      {:ok, _view, html} = live(chat_conn(conn, creator.nickname), "/lobby/#{token}")

      # The desktop opts out of layout persistence (clean slate each open)...
      assert html =~ ~s(data-persist="false")
      # ...and offers a double-clickable shortcut per feature.
      for feature <- ~w(call file game chat conn) do
        assert html =~ ~s(data-testid="lobby-shortcut-#{feature}")
        assert html =~ ~s(data-window-shortcut="#{feature}")
      end
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
    test "the game picker lists available games once the Games window is opened", %{
      conn: conn,
      token: token,
      creator: creator,
      peer: peer
    } do
      view = connect_both(conn, token, creator, peer)

      # The Games window is server-managed: its island mounts only while open.
      refute render(view) =~ ~s(data-testid="lobby-window-game")

      render_hook(view, "window_open", %{"id" => "game"})
      html = render(view)

      assert html =~ ~s(data-testid="lobby-window-game")
      assert html =~ ~s(data-testid="lobby-game-panel")
      assert html =~ "Hex Pong"
    end

    test "closing the Games window client-side unmounts its island", %{
      conn: conn,
      token: token,
      creator: creator,
      peer: peer
    } do
      view = connect_both(conn, token, creator, peer)

      render_hook(view, "window_open", %{"id" => "game"})
      assert render(view) =~ ~s(data-testid="lobby-window-game")

      render_hook(view, "window_closed", %{"id" => "game"})
      refute render(view) =~ ~s(data-testid="lobby-window-game")
    end

    test "window_open ignores ids that are not server-managed windows", %{
      conn: conn,
      token: token,
      creator: creator,
      peer: peer
    } do
      view = connect_both(conn, token, creator, peer)

      html = render_hook(view, "window_open", %{"id" => "bogus"})
      refute html =~ ~s(data-window-id="bogus")
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

      creator_view
      |> form(~s([data-testid="chat-input-form"]), %{input: "hi there"})
      |> render_submit()

      Process.sleep(50)

      assert render(peer_view) =~ "hi there"
    end

    test "the /me command renders an action line for both peers", %{
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

      creator_view
      |> form(~s([data-testid="chat-input-form"]), %{input: "/me waves hello"})
      |> render_submit()

      Process.sleep(50)

      html = render(peer_view)
      assert html =~ "waves hello"
      # The action body is prefixed with "* "; the author is an interactive nick
      # handle in the meta column (no angle brackets).
      assert html =~ "* waves hello"
      assert html =~ ~s(data-nick="#{creator.nickname}")
      refute html =~ "&lt;#{creator.nickname}&gt;"
    end

    test "starting a call shows media controls",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      render_hook(view, "lobby_media_call_started", %{"type" => "video"})
      html = render(view)
      assert html =~ "End call"
      assert html =~ ~s(data-testid="lobby-media-panel")
    end

    test "the idle Call window offers start buttons (so the Call shortcut is actionable)",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)
      html = render(view)

      # No call yet: the Call window body offers Start audio / Start video directly.
      assert html =~ ~s(data-testid="lobby-call-start-audio")
      assert html =~ ~s(data-testid="lobby-call-start-video")

      # Clicking Start audio begins a call (media controls appear).
      render_hook(view, "lobby_media_call_started", %{"type" => "audio"})
      assert render(view) =~ "End call"
    end

    test "the statistics window is always complete and updates per feature from lobby_stats",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      # Every feature section renders from the start — zeroed, no call needed.
      html = render(view)
      assert html =~ ~s(data-testid="lobby-network-panel")
      assert html =~ "Connection"
      assert html =~ "Audio"
      assert html =~ "Video"
      assert html =~ "Games"
      assert html =~ "Files"

      # An always-on per-feature sample populates the isolated metrics.
      render_hook(view, "lobby_stats", %{
        "connection" => %{
          "level" => "good",
          "label" => "Good",
          "mos" => 4.2,
          "rtt_ms" => 30,
          "jitter_ms" => 2,
          "loss_pct" => 0,
          "available_kbps" => 1200
        },
        "audio" => %{
          "active" => true,
          "in_kbps" => 40,
          "out_kbps" => 38,
          "loss_pct" => 0,
          "jitter_ms" => 3
        },
        "video" => %{
          "active" => true,
          "in_kbps" => 800,
          "out_kbps" => 700,
          "loss_pct" => 1,
          "jitter_ms" => 5,
          "fps" => 30,
          "width" => 1280,
          "height" => 720,
          "freeze_count" => 0,
          "limitation" => "none"
        },
        "game" => %{
          "active" => false,
          "state" => "open",
          "sent_kbps" => 0,
          "recv_kbps" => 0,
          "messages" => 0
        },
        "file" => %{
          "active" => false,
          "state" => "closed",
          "sent_kbps" => 0,
          "recv_kbps" => 0,
          "messages" => 0
        }
      })

      html = render(view)
      assert html =~ "1280×720"
      assert html =~ "30 ms"
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

    test "closing the Call window (X) ends the call and closes the window",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)
      render_hook(view, "lobby_media_call_started", %{"type" => "video"})

      # X on an active Call window is server-driven: it tears the call down and
      # asks the hook to echo back so our state clears (notify: true).
      render_click(view, "end_call", %{})
      assert_push_event(view, "lobby_media_end_call", %{notify: true})

      # The media hook then reports the call ended → window closes, call clears.
      render_hook(view, "lobby_media_call_ended", %{})
      assert_push_event(view, "window_command", %{action: "close", id: "call"})
      refute render(view) =~ "End call"
    end

    test "the peer starting a call auto-joins us recvonly: window opens, surface renders, media off",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      # Before the peer shares, there is no remote video element to attach to.
      refute render(view) =~ ~s(id="lobby-remote-video")

      # The peer starts a video call. We auto-join as a pure receiver: the hook is
      # told to enter recvonly mode, the window opens, and the surface renders.
      SessionServer.set_media(token, peer.id, true, true)

      assert_push_event(view, "lobby_media_join", %{})
      assert_push_event(view, "window_command", %{action: "open", id: "call"})

      html = render(view)
      assert html =~ ~s(id="lobby-remote-video")
      assert html =~ ~s(id="lobby-remote-audio")
      # We are in the call but sending nothing: controls offer to enable mic/camera,
      # and we can leave the call we were placed into.
      assert html =~ ~s(data-lobby-media-action="enable-audio")
      assert html =~ ~s(data-lobby-media-action="enable-video")
      assert html =~ "End call"
      # No mute/camera toggles yet — we are not sending.
      refute html =~ ~s(data-lobby-media-action="mute")
      refute html =~ ~s(data-lobby-media-action="camera")
    end

    test "an auto-joined receiver enabling the camera flips it to an on/off toggle",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)
      SessionServer.set_media(token, peer.id, true, true)
      assert_push_event(view, "lobby_media_join", %{})

      # The media hook reports we turned our camera on (no mic).
      render_hook(view, "lobby_media_call_started", %{"audio_on" => false, "video_on" => true})
      html = render(view)

      # Camera is now an on/off toggle; the mic is still enable-on-demand.
      assert html =~ ~s(data-lobby-media-action="camera")
      assert html =~ ~s(data-lobby-media-action="enable-audio")
      refute html =~ ~s(data-lobby-media-action="enable-video")
    end

    test "the peer ending the call leaves an auto-joined receiver",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)
      SessionServer.set_media(token, peer.id, true, true)
      assert_push_event(view, "lobby_media_join", %{})

      # The peer stops all media. We were only receiving, so we leave the call.
      SessionServer.set_media(token, peer.id, false, false)
      assert_push_event(view, "lobby_media_end_call", %{notify: true})
    end

    test "a peer camera update alone does not fabricate a local call",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      # A bare peer-camera event (no media-changed) must not put us in a call.
      send(view.pid, %{event: "lobby_peer_camera", payload: %{off: true, from: peer.id}})

      html = render(view)
      refute html =~ "End call"
      refute html =~ ~s(data-lobby-media-action="enable-audio")
    end

    test "an auto-joined receiver's camera control reflects the real state, not inverted",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)
      SessionServer.set_media(token, peer.id, true, true)
      assert_push_event(view, "lobby_media_join", %{})

      # We turn our own camera on. The control must read "Camera Off" (the action to
      # turn it off) — it used to start inverted because auto-join pre-set camera-off.
      render_hook(view, "lobby_media_call_started", %{"audio_on" => false, "video_on" => true})
      html = render(view)

      assert html =~ ~s(data-lobby-media-action="camera")
      assert html =~ ~s(title="Camera Off")
      refute html =~ ~s(title="Camera On")
    end

    test "the X on the Game window quits and unmounts it",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      render_hook(view, "window_open", %{"id" => "game"})
      assert render(view) =~ ~s(data-testid="lobby-window-game")

      render_click(view, "end_game", %{})
      # The island asks the host to unmount via {:close_window, "game"} (async
      # under LiveViewTest) — flush the update cycle before asserting.
      render(view)
      refute render(view) =~ ~s(data-testid="lobby-window-game")
    end

    test "the taskbar game badge tracks the active game (C2 read-model)",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)
      refute render(view) =~ "●"

      # Entering "playing" makes the island mirror an active summary to the host,
      # which lights the taskbar badge. If the host swallowed the {:feature_summary}
      # tuple in its catch-all, the badge would never appear.
      send(view.pid, %{
        event: "lobby_game_status_changed",
        payload: %{status: "playing", game_id: "hex_pong", host_id: creator.id}
      })

      Process.sleep(50)
      assert render(view) =~ "●"

      # Going idle clears the summary and the badge.
      send(view.pid, %{event: "lobby_game_status_changed", payload: %{status: "idle"}})
      Process.sleep(50)
      refute render(view) =~ "●"
    end

    test "the X on the Files window cancels and closes it",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      render_click(view, "ft_cancel", %{})
      # The File island drives its own window via send_update (async) — flush first.
      render(view)
      assert_push_event(view, "window_command", %{action: "close", id: "file"})
    end

    test "the file transfer hook stays mounted so closing the window can't kill a transfer",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      # The island is always mounted, so the FileTransferHook (and its data channel)
      # lives for the whole connection.
      assert render(view) =~ ~s(phx-hook="FileTransferHook")

      # Cancelling/closing the Files window only hides it...
      render_click(view, "ft_cancel", %{})
      render(view)

      # ...the island and its hook are still in the DOM.
      html = render(view)
      assert html =~ ~s(phx-hook="FileTransferHook")
      assert html =~ ~s(id="lobby-file-transfer")
    end

    test "the taskbar file badge tracks transfer progress (C2 read-model)",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      view = connect_both(conn, token, creator, peer)

      render_hook(view, "ft_offer_sent", %{"file_name" => "a.bin", "formatted_size" => "1 MB"})
      render_hook(view, "ft_progress", %{"percent" => 50, "speed" => "1 MB/s"})
      Process.sleep(50)

      # The island mirrors a {status, percent} summary to the host, which lights the
      # taskbar badge. A swallowed {:feature_summary} tuple would leave it blank.
      assert render(view) =~ "50%"
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
