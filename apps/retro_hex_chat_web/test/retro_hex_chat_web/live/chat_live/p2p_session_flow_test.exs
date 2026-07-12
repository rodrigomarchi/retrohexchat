defmodule RetroHexChatWeb.ChatLive.P2PSessionFlowTest do
  @moduledoc """
  In-chat P2P session flow (F2 of docs/plans/p2p-chat-integracao.md):
  invite → accept/decline via the PM card, cancel via the status bar, and the
  one-session-at-a-time switch. Asserts on synchronous LiveView state
  (`:sys.get_state`) and persisted domain rows — never on async stream diffs.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.RegisteredNick

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp mount_pair(conn, nick_a, nick_b) do
    a = register(nick_a)
    b = register(nick_b)

    {:ok, view_a, _} = live(chat_conn(conn, nick_a, pre_identified: true), "/chat")
    {:ok, view_b, _} = live(chat_conn(conn, nick_b, pre_identified: true), "/chat")

    %{a: a, b: b, view_a: view_a, view_b: view_b}
  end

  defp p2p_assigns(view), do: :sys.get_state(view.pid).socket.assigns.p2p_session

  defp flush(view), do: :sys.get_state(view.pid)

  defp submit_outgoing_setup(view, params \\ %{}) do
    render_submit(view, "p2p_setup_accept", %{
      "p2p_setup" =>
        Map.merge(%{"audio" => "true", "video" => "true", "turn_only" => "false"}, params)
    })
  end

  defp invite(ctx, params \\ %{}) do
    submit_command_sync(ctx.view_a, "/p2p #{ctx.b.nickname}")
    assert render(ctx.view_a) =~ "p2p-setup-form"
    refute Lobby.active_session_for_user(ctx.a.id)

    submit_outgoing_setup(ctx.view_a, params)

    session = Lobby.active_session_for_user(ctx.a.id)
    assert session, "expected P2P setup submit to create a session"
    session
  end

  defp accept_invite(view, token, params \\ %{}) do
    render_click(view, "p2p_accept_invite", %{"token" => token})

    render_submit(view, "p2p_setup_accept", %{
      "p2p_setup" =>
        Map.merge(%{"audio" => "true", "video" => "true", "turn_only" => "false"}, params)
    })
  end

  describe "invite → accept" do
    test "creator setup is required before the invite is sent", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgs#{uid()}", "p2pgt#{uid()}")

      submit_command_sync(ctx.view_a, "/p2p #{ctx.b.nickname}")

      html = render(ctx.view_a)
      assert html =~ "p2p-setup-form"
      assert html =~ "Prepare P2P Invite"
      assert html =~ "Send invite"
      assert p2p_assigns(ctx.view_a) == nil
      refute Lobby.active_session_for_user(ctx.a.id)

      render_click(ctx.view_a, "p2p_setup_cancel", %{})

      assert p2p_assigns(ctx.view_a) == nil
      refute Lobby.active_session_for_user(ctx.a.id)
      refute render(ctx.view_a) =~ "p2p-setup-form"
    end

    test "creator setup seeds media defaults before the peer accepts", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgu#{uid()}", "p2pgv#{uid()}")

      session =
        invite(ctx, %{
          "audio" => "false",
          "video" => "false",
          "audio_input_id" => "creator-mic",
          "video_input_id" => "creator-cam",
          "audio_output_id" => "creator-out"
        })

      assert %{state: :invite_sent, role: :creator, media_mode: "receive"} =
               p2p_assigns(ctx.view_a)

      assert p2p_assigns(ctx.view_a).device_preferences == %{
               audio_input_id: "creator-mic",
               video_input_id: "creator-cam",
               audio_output_id: "creator-out"
             }

      assert {:ok, %{status: "pending"}} = Lobby.get_session(session.token)
    end

    test "creator holds :invite_sent and the peer's accept joins both", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfa#{uid()}", "p2pfb#{uid()}")
      session = invite(ctx)

      assert %{state: :invite_sent, role: :creator} = p2p_assigns(ctx.view_a)
      assert render(ctx.view_a) =~ "status-bar-p2p"

      html = render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session.token})
      assert html =~ "p2p-setup-dialog"
      assert p2p_assigns(ctx.view_b) == nil

      render_submit(ctx.view_b, "p2p_setup_accept", %{
        "p2p_setup" => %{"media_mode" => "audio", "turn_only" => "false"}
      })

      assert %{state: :joining, role: :peer} = p2p_assigns(ctx.view_b)
      assert p2p_assigns(ctx.view_b).media_mode == "audio"

      # The creator joins on the peer's lobby_peer_joined (subscribe-only
      # until then, so the standalone page can still claim the session);
      # only after that do BOTH count as joined and the status flips.
      flush(ctx.view_a)
      assert %{state: :joining} = p2p_assigns(ctx.view_a)
      assert {:ok, %{status: "lobby"}} = Lobby.get_session(session.token)
    end

    test "the invited peer sees accept/decline buttons on the PM card", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfc#{uid()}", "p2pfd#{uid()}")
      invite(ctx)

      flush(ctx.view_b)
      render_click(ctx.view_b, "switch_pm", %{"nickname" => ctx.a.nickname})

      html = render(ctx.view_b)
      assert html =~ "session-card-accept"
      assert html =~ "session-card-decline"
    end

    test "cancelling the setup leaves the invite pending and does not join", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgk#{uid()}", "p2pgl#{uid()}")
      session = invite(ctx)

      assert render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session.token}) =~
               "p2p-setup-dialog"

      render_click(ctx.view_b, "p2p_setup_cancel", %{})

      assert p2p_assigns(ctx.view_b) == nil
      assert {:ok, %{status: "pending"}} = Lobby.get_session(session.token)
    end

    test "setup checkboxes and devices seed the P2P media defaults", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgq#{uid()}", "p2pgr#{uid()}")
      session = invite(ctx)

      render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session.token})

      render_submit(ctx.view_b, "p2p_setup_accept", %{
        "p2p_setup" => %{
          "audio" => "true",
          "video" => "false",
          "audio_input_id" => "mic-1",
          "video_input_id" => "cam-1",
          "audio_output_id" => "out-1",
          "turn_only" => "false"
        }
      })

      assert %{state: :joining, media_mode: "audio"} = p2p_assigns(ctx.view_b)

      assert p2p_assigns(ctx.view_b).device_preferences == %{
               audio_input_id: "mic-1",
               video_input_id: "cam-1",
               audio_output_id: "out-1"
             }
    end
  end

  describe "decline and cancel" do
    test "declining closes the pending session and clears the creator state", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfe#{uid()}", "p2pff#{uid()}")
      session = invite(ctx)

      render_click(ctx.view_b, "p2p_decline_invite", %{"token" => session.token})

      assert {:ok, %{status: "closed", closed_reason: "declined"}} =
               Lobby.get_session(session.token)

      flush(ctx.view_a)
      assert p2p_assigns(ctx.view_a) == nil
      refute render(ctx.view_a) =~ "status-bar-p2p"
    end

    test "the creator cancels a pending invite from the status bar", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfg#{uid()}", "p2pfh#{uid()}")
      session = invite(ctx)

      render_click(ctx.view_a, "p2p_statusbar_stop", %{})
      flush(ctx.view_a)

      assert {:ok, %{status: "closed", closed_reason: "invite_cancelled"}} =
               Lobby.get_session(session.token)

      assert p2p_assigns(ctx.view_a) == nil
    end
  end

  describe "statistics window" do
    test "opens via the P2P menu action, shows telemetry, and closes with the session",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfo#{uid()}", "p2pfp#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)

      # Menu bar / start menu dispatch the same semantic action.
      render_click(ctx.view_a, "toolbar_action", %{"action" => "p2p_open_stats"})
      assert render(ctx.view_a) =~ "p2p-stats-window"

      # A telemetry sample from the WebRTC hook lands normalized in the panel.
      render_click(ctx.view_a, "lobby_stats", %{"connection" => %{"rtt_ms" => 42}})
      assert p2p_assigns(ctx.view_a).stats.connection.rtt_ms == 42

      # Clicking the status-bar area focuses the open P2P windows (no crash,
      # window stays open).
      render_click(ctx.view_a, "p2p_statusbar_click", %{})
      assert render(ctx.view_a) =~ "p2p-stats-window"

      # Ending the session tears the window down with it.
      render_click(ctx.view_a, "p2p_statusbar_stop", %{})
      render_click(ctx.view_a, "p2p_confirm_end", %{})
      flush(ctx.view_a)
      assert p2p_assigns(ctx.view_a) == nil
      refute render(ctx.view_a) =~ "p2p-stats-window"
    end
  end

  describe "files window" do
    test "mounts with the session, reacts to ft_* events, and feeds the summary",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfq#{uid()}", "p2pfr#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)

      # The window (and its island/hook) is always mounted while joined.
      assert render(ctx.view_b) =~ "p2p-files-window"

      # The WebRTC hook reports the link up; the panel unlocks on :connected.
      render_click(ctx.view_b, "lobby_connected", %{})
      assert %{state: :connected} = p2p_assigns(ctx.view_b)

      # An incoming offer flows hook → host adapter → island, opens the
      # window and mirrors the C2 summary up to the host.
      render_click(ctx.view_b, "file_transfer_ready", %{})

      render_click(ctx.view_b, "ft_offer_received", %{
        "file_name" => "relatorio.pdf",
        "formatted_size" => "1.2 MB"
      })

      flush(ctx.view_b)

      assert %{file_summary: %{status: "offer_received", file_name: "relatorio.pdf"}} =
               p2p_assigns(ctx.view_b)

      assert render(ctx.view_b) =~ "relatorio.pdf"
    end
  end

  describe "call window" do
    test "starting an audio call records media presence and mirrors the summary",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfs#{uid()}", "p2pft#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)
      render_click(ctx.view_a, "lobby_connected", %{})

      assert render(ctx.view_a) =~ "p2p-call-window"

      # Menu action → island → domain records this peer's media presence.
      render_click(ctx.view_a, "toolbar_action", %{"action" => "p2p_start_audio"})
      flush(ctx.view_a)
      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.creator == %{audio: true, video: false}

      # The media hook echoes the call start; the C2 summary reaches the host.
      render_click(ctx.view_a, "lobby_media_call_started", %{"type" => "audio"})
      flush(ctx.view_a)
      assert %{call_summary: %{type: "audio"}} = p2p_assigns(ctx.view_a)

      # Ending the call clears the summary and the media presence.
      render_click(ctx.view_a, "lobby_media_call_ended", %{})
      flush(ctx.view_a)
      assert p2p_assigns(ctx.view_a).call_summary == nil
      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.creator == %{audio: false, video: false}
    end
  end

  describe "games window" do
    test "a full propose → accept → finish cycle drives both windows", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfu#{uid()}", "p2pfv#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)
      render_click(ctx.view_a, "lobby_connected", %{})
      flush(ctx.view_b)

      # A proposes; the request opens the (managed) window on BOTH sides.
      render_click(ctx.view_a, "propose_game", %{"game_id" => "hex_pong"})
      flush(ctx.view_a)
      flush(ctx.view_b)
      assert render(ctx.view_a) =~ "p2p-games-window"
      assert render(ctx.view_b) =~ "p2p-games-window"

      # B accepts: the game starts and the C2 summary flags it active.
      render_click(ctx.view_b, "respond_game", %{"accepted" => "true"})
      flush(ctx.view_a)
      flush(ctx.view_b)
      assert {:ok, %{game: %{status: "playing"}}} = Lobby.session_info(session.token)
      assert %{game_summary: %{active?: true}} = p2p_assigns(ctx.view_a)

      # The host reports the authoritative result; both islands show it and
      # the session stays connected.
      render_click(ctx.view_a, "lobby_game_result", %{
        "score" => %{"p1" => 5, "p2" => 3},
        "winner" => 1
      })

      flush(ctx.view_a)
      assert {:ok, %{game: %{status: "finished"}}} = Lobby.session_info(session.token)
      assert render(ctx.view_a) =~ "p2p-games-window"

      # Quitting via the window returns the domain to idle and unmounts.
      render_click(ctx.view_a, "end_game", %{})
      flush(ctx.view_a)
      assert {:ok, %{game: %{status: "idle"}}} = Lobby.session_info(session.token)
      refute render(ctx.view_a) =~ "p2p-games-window"
    end
  end

  describe "window burst on connect" do
    test "connecting opens all four session windows; ending closes them all", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgc#{uid()}", "p2pgd#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)

      render_click(ctx.view_a, "lobby_connected", %{})

      assigns = :sys.get_state(ctx.view_a.pid).socket.assigns
      assert "p2p-stats" in assigns.open_windows
      assert "p2p-games" in assigns.open_windows

      html = render(ctx.view_a)

      for window <- ~w(p2p-call-window p2p-files-window p2p-games-window p2p-stats-window) do
        assert html =~ window
      end

      # Everything but the Call window is sent to the taskbar minimized.
      for id <- ~w(p2p-stats p2p-games p2p-files) do
        assert_push_event(ctx.view_a, "window_command", %{action: "minimize", id: ^id})
      end

      # Once the media hook reports ready, the call auto-starts (mic+camera)
      # exactly once — media presence lands in the domain.
      render_click(ctx.view_a, "lobby_media_hook_ready", %{})
      flush(ctx.view_a)
      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.creator == %{audio: true, video: true}
      assert p2p_assigns(ctx.view_a).auto_call_started

      # A second ready report (hook re-mount) must not restart the call.
      render_click(ctx.view_a, "lobby_media_hook_ready", %{})
      assert p2p_assigns(ctx.view_a).auto_call_started

      # Ending the session tears every session window down with it.
      render_click(ctx.view_a, "p2p_statusbar_stop", %{})
      render_click(ctx.view_a, "p2p_confirm_end", %{})
      flush(ctx.view_a)

      html = render(ctx.view_a)

      for window <- ~w(p2p-call-window p2p-files-window p2p-games-window p2p-stats-window) do
        refute html =~ window
      end
    end

    test "receive-only setup opens the windows but does not auto-start local media",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pgm#{uid()}", "p2pgn#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token, %{"media_mode" => "receive"})
      flush(ctx.view_a)

      render_click(ctx.view_b, "lobby_connected", %{})
      render_click(ctx.view_b, "lobby_media_hook_ready", %{})

      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.peer == %{audio: false, video: false}
      assert p2p_assigns(ctx.view_b).auto_call_started
    end

    test "call mini mode and stats docking drive the window manager", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgo#{uid()}", "p2pgp#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)
      render_click(ctx.view_a, "lobby_connected", %{})

      render_click(ctx.view_a, "p2p_toggle_call_mini", %{})
      assert p2p_assigns(ctx.view_a).call_mini
      assert_push_event(ctx.view_a, "window_command", %{action: "open", id: "p2p-call"})

      assert_push_event(ctx.view_a, "window_command", %{
        action: "set_geometry",
        id: "p2p-call",
        width: 300,
        height: 236,
        anchor: "bottom_right"
      })

      assert render(ctx.view_a) =~ ~s(data-call-mini="true")

      render_click(ctx.view_a, "p2p_dock_stats", %{})
      refute p2p_assigns(ctx.view_a).call_mini
      assert "p2p-stats" in :sys.get_state(ctx.view_a.pid).socket.assigns.open_windows
      assert_push_event(ctx.view_a, "window_command", %{action: "open", id: "p2p-stats"})
      assert_push_event(ctx.view_a, "window_command", %{action: "open", id: "p2p-call"})

      assert_push_event(ctx.view_a, "window_command", %{
        action: "dock_pair",
        id: "p2p-call",
        secondary_id: "p2p-stats",
        secondary_width: 390
      })
    end

    test "closing any session window asks to disconnect; confirming ends the session",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pgg#{uid()}", "p2pgh#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)
      render_click(ctx.view_a, "lobby_connected", %{})

      # The X routes to the confirm — nothing ends yet.
      render_click(ctx.view_a, "p2p_window_close", %{})
      assert {:ok, %{status: "connected"}} = Lobby.get_session(session.token)
      assert %{state: :connected} = p2p_assigns(ctx.view_a)

      # Confirming the dialog disconnects the whole session.
      render_click(ctx.view_a, "p2p_confirm_end", %{})
      flush(ctx.view_a)
      assert {:ok, %{status: "closed"}} = Lobby.get_session(session.token)
      assert p2p_assigns(ctx.view_a) == nil
      refute render(ctx.view_a) =~ "p2p-call-window"
    end

    test "the burst is skipped on a mobile viewport", %{conn: conn} do
      ctx = mount_pair(conn, "p2pge#{uid()}", "p2pgf#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)

      render_click(ctx.view_a, "viewport_info", %{"width" => 390})
      render_click(ctx.view_a, "lobby_connected", %{})

      assigns = :sys.get_state(ctx.view_a.pid).socket.assigns
      refute "p2p-stats" in assigns.open_windows
      refute "p2p-games" in assigns.open_windows
    end
  end

  describe "PM absorption (p2p_system)" do
    defp p2p_system_messages(nick_a, nick_b) do
      nick_a
      |> ChatQueries.list_private_messages(nick_b)
      |> Enum.filter(&(&1.type == "p2p_system"))
    end

    test "lifecycle notices persist into the PM with a single writer", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfw#{uid()}", "p2pfx#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)

      # Both hooks report connected; only the CREATOR persists the line.
      render_click(ctx.view_a, "lobby_connected", %{})
      render_click(ctx.view_b, "lobby_connected", %{})
      flush(ctx.view_a)
      flush(ctx.view_b)

      assert [connected_msg] = p2p_system_messages(ctx.a.nickname, ctx.b.nickname)
      assert connected_msg.content =~ "connected"

      # Ending persists exactly one more line, written by the ender.
      render_click(ctx.view_a, "p2p_statusbar_stop", %{})
      render_click(ctx.view_a, "p2p_confirm_end", %{})
      flush(ctx.view_a)
      flush(ctx.view_b)

      assert [ended_msg, ^connected_msg] = p2p_system_messages(ctx.a.nickname, ctx.b.nickname)
      assert ended_msg.content =~ "ended the P2P session"
      assert ended_msg.sender_nickname == ctx.a.nickname
    end

    test "declining persists the decliner's p2p_system line", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfy#{uid()}", "p2pfz#{uid()}")
      session = invite(ctx)

      render_click(ctx.view_b, "p2p_decline_invite", %{"token" => session.token})
      flush(ctx.view_a)

      assert [msg] = p2p_system_messages(ctx.a.nickname, ctx.b.nickname)
      assert msg.content =~ "declined"
      assert msg.sender_nickname == ctx.b.nickname
    end

    test "the peer PM tab carries a stateful P2P glyph from invite to connected", %{conn: conn} do
      ctx = mount_pair(conn, "p2pga#{uid()}", "p2pgb#{uid()}")
      session = invite(ctx)

      assert render(ctx.view_a) =~ ~s(data-testid="tab-p2p-glyph")
      assert render(ctx.view_a) =~ ~s(data-p2p-state="pending")

      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)

      assert render(ctx.view_a) =~ ~s(data-p2p-state="connecting")

      render_click(ctx.view_a, "lobby_connected", %{})
      assert render(ctx.view_a) =~ ~s(data-p2p-state="connected")
    end
  end

  describe "ignore and P2P safety" do
    test "ignoring the active peer closes the session and blocks a new invite", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgi#{uid()}", "p2pgj#{uid()}")
      session = invite(ctx)
      accept_invite(ctx.view_b, session.token)
      flush(ctx.view_a)

      submit_command_sync(ctx.view_a, "/ignore #{ctx.b.nickname}")
      flush(ctx.view_a)
      flush(ctx.view_b)

      assert {:ok, %{status: "closed", closed_reason: "user_blocked"}} =
               Lobby.get_session(session.token)

      assert p2p_assigns(ctx.view_a) == nil
      assert p2p_assigns(ctx.view_b) == nil

      submit_command_sync(ctx.view_b, "/p2p #{ctx.a.nickname}")
      refute Lobby.active_session_for_user(ctx.b.id)
      refute render(ctx.view_b) =~ "p2p-setup-form"
    end
  end

  describe "one session at a time (switch)" do
    test "accepting a second invite asks to switch and ends the first session", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfi#{uid()}", "p2pfj#{uid()}")
      c = register("p2pfk#{uid()}")
      {:ok, view_c, _} = live(chat_conn(conn, c.nickname, pre_identified: true), "/chat")

      # A ↔ B session up and joined (A joins upon B's accept).
      session_ab = invite(ctx)
      accept_invite(ctx.view_b, session_ab.token)
      flush(ctx.view_a)
      assert %{state: :joining} = p2p_assigns(ctx.view_b)

      # C invites B while B is busy — the invite must be delivered normally.
      submit_command_sync(view_c, "/p2p #{ctx.b.nickname}")
      assert render(view_c) =~ "p2p-setup-form"
      submit_outgoing_setup(view_c)

      session_cb = Lobby.active_session_for_user(c.id)
      assert session_cb

      # Accepting stashes the target and opens the confirm; nothing ends yet.
      flush(ctx.view_b)
      render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session_cb.token})
      assert %{state: :joining} = p2p_assigns(ctx.view_b)
      assert {:ok, %{status: "lobby"}} = Lobby.get_session(session_ab.token)

      # Confirming ends A↔B and joins C↔B.
      render_click(ctx.view_b, "p2p_confirm_switch", %{})
      assert render(ctx.view_b) =~ "p2p-setup-dialog"

      render_submit(ctx.view_b, "p2p_setup_accept", %{
        "p2p_setup" => %{"media_mode" => "receive", "turn_only" => "false"}
      })

      assert {:ok, %{status: "closed"}} = Lobby.get_session(session_ab.token)
      assert %{state: :joining, token: token} = p2p_assigns(ctx.view_b)
      assert token == session_cb.token
      assert p2p_assigns(ctx.view_b).media_mode == "receive"

      flush(ctx.view_a)
      assert p2p_assigns(ctx.view_a) == nil
    end

    test "an outgoing /p2p while busy confirms before the invite PM is sent", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfl#{uid()}", "p2pfm#{uid()}")
      c = register("p2pfn#{uid()}")
      {:ok, _view_c, _} = live(chat_conn(conn, c.nickname, pre_identified: true), "/chat")

      session_ab = invite(ctx)
      accept_invite(ctx.view_b, session_ab.token)
      flush(ctx.view_a)

      # A tries to invite C while in a session with B: session B stays alive
      # until the switch is confirmed.
      submit_command_sync(ctx.view_a, "/p2p #{c.nickname}")
      assert %{token: token_ab} = p2p_assigns(ctx.view_a)
      assert token_ab == session_ab.token
      assert {:ok, %{status: "lobby"}} = Lobby.get_session(session_ab.token)
      refute Lobby.active_session_for_user(c.id)

      render_click(ctx.view_a, "p2p_confirm_switch", %{})

      assert {:ok, %{status: "closed"}} = Lobby.get_session(session_ab.token)
      assert p2p_assigns(ctx.view_a) == nil
      assert render(ctx.view_a) =~ "p2p-setup-form"

      submit_outgoing_setup(ctx.view_a)

      assert %{state: :invite_sent, role: :creator, token: new_token} = p2p_assigns(ctx.view_a)
      assert new_token != session_ab.token
    end
  end
end
