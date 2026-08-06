defmodule RetroHexChatWeb.ChatLive.P2PSessionFlowTest do
  @moduledoc """
  In-chat P2P session flow (docs/plans/p2p-fluxo-como-conferencia.md):
  PM entry → send request → accept/decline via the PM header, cancel via the
  status bar, and the one-session-at-a-time switch. Asserts on synchronous LiveView state
  (`:sys.get_state`) and persisted domain rows — never on async stream diffs.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Calls.Events, as: CallEvents
  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.RegisteredNick

  @event_timeout 500

  defmodule AlwaysLimited do
    @moduledoc false
    @behaviour RetroHexChat.P2P.SignalingRateLimit

    @retry_after_ms 4_200

    @impl true
    @spec check_signal_rate(String.t(), integer()) :: {:error, {:rate_limited, pos_integer()}}
    def check_signal_rate(_token, _user_id), do: {:error, {:rate_limited, @retry_after_ms}}
  end

  defp limit_all_signals do
    previous = Application.get_env(:retro_hex_chat, :signaling_rate_limiter)
    Application.put_env(:retro_hex_chat, :signaling_rate_limiter, AlwaysLimited)
    on_exit(fn -> Application.put_env(:retro_hex_chat, :signaling_rate_limiter, previous) end)
  end

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp mount_pair(conn, nick_a, nick_b, opts \\ []) do
    a = register(nick_a)
    b = register(nick_b)
    trusted_a = maybe_remember_device(a, Keyword.get(opts, :trusted_a, false))
    trusted_b = maybe_remember_device(b, Keyword.get(opts, :trusted_b, false))

    {:ok, view_a, _} =
      live(chat_conn(conn, nick_a, chat_conn_opts(trusted_a)), "/chat")

    {:ok, view_b, _} =
      live(chat_conn(conn, nick_b, chat_conn_opts(trusted_b)), "/chat")

    %{
      a: a,
      b: b,
      device_a: trusted_device(trusted_a),
      device_b: trusted_device(trusted_b),
      view_a: view_a,
      view_b: view_b
    }
  end

  defp maybe_remember_device(nick, true) do
    {:ok, result} = TrustedDevices.remember_nick(nil, nick.nickname)
    result
  end

  defp maybe_remember_device(_nick, false), do: nil

  defp chat_conn_opts(nil), do: [pre_identified: true]

  defp chat_conn_opts(%{cookie_value: cookie}) do
    [pre_identified: true, trusted_device_cookie: cookie]
  end

  defp trusted_device(%{device: device}), do: device
  defp trusted_device(nil), do: nil

  defp p2p_assigns(view), do: :sys.get_state(view.pid).socket.assigns.p2p_session

  defp flush(view), do: :sys.get_state(view.pid)

  defp attach_call_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        CallEvents.recovery_transition_event(),
        CallEvents.client_error_event(),
        CallEvents.signaling_replay_event()
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:call_telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

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

    on_exit(fn -> stop_session_server(session.token) end)

    session
  end

  defp accept_invite(target, token, params \\ %{})

  defp accept_invite(%{view_a: creator_view, view_b: peer_view}, token, params) do
    accept_invite(peer_view, token, params)
    wait_for_lobby_joined(creator_view, token)
  end

  defp accept_invite(view, token, params) do
    render_click(view, "p2p_accept_invite", %{"token" => token})

    render_submit(view, "p2p_setup_accept", %{
      "p2p_setup" =>
        Map.merge(%{"audio" => "true", "video" => "true", "turn_only" => "false"}, params)
    })
  end

  defp wait_for_lobby_joined(view, token, attempts \\ 50)

  defp wait_for_lobby_joined(_view, token, 0) do
    flunk("expected P2P session #{token} to reach lobby with both participants joined")
  end

  defp wait_for_lobby_joined(view, token, attempts) do
    flush(view)

    case Lobby.session_info(token) do
      {:ok, %{creator_joined: true, peer_joined: true, session: %{status: status}}}
      when status in ["lobby", "connected"] ->
        :ok

      _ ->
        Process.sleep(10)
        wait_for_lobby_joined(view, token, attempts - 1)
    end
  end

  defp wait_until(fun, attempts \\ 50)

  defp wait_until(_fun, 0), do: flunk("condition was not met in time")

  defp wait_until(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(20)
      wait_until(fun, attempts - 1)
    end
  end

  defp hold_lobby_slot(token, user_id) do
    parent = self()

    holder =
      spawn(fn ->
        result = retry_join_lobby_slot(token, user_id, 50)
        send(parent, {:lobby_slot_holder_joined, self(), result})

        receive do
          :release -> :ok
        end
      end)

    assert_receive {:lobby_slot_holder_joined, ^holder, result}, @event_timeout
    assert result == :ok

    on_exit(fn ->
      if Process.alive?(holder), do: send(holder, :release)
    end)

    holder
  end

  defp retry_join_lobby_slot(token, user_id, attempts)

  defp retry_join_lobby_slot(token, user_id, 0), do: Lobby.join_session(token, user_id)

  defp retry_join_lobby_slot(token, user_id, attempts) do
    case Lobby.join_session(token, user_id) do
      :ok ->
        :ok

      {:error, :already_joined} ->
        Process.sleep(10)
        retry_join_lobby_slot(token, user_id, attempts - 1)

      error ->
        error
    end
  end

  defp stop_session_server(token) do
    case RetroHexChat.Lobby.Registry.lookup(token) do
      {:ok, pid} -> stop_session_server_pid(pid)
      {:error, :not_found} -> :ok
    end
  end

  defp stop_session_server_pid(pid) do
    GenServer.stop(pid, :normal)
  catch
    :exit, _reason -> :ok
  end

  describe "invite → accept" do
    test "creator setup is required before the invite is sent", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgs#{uid()}", "p2pgt#{uid()}")

      submit_command_sync(ctx.view_a, "/p2p #{ctx.b.nickname}")

      html = render(ctx.view_a)
      assert html =~ "p2p-setup-form"
      assert html =~ "Start P2P Session"
      assert html =~ "Send invite"
      assert p2p_assigns(ctx.view_a) == nil
      refute Lobby.active_session_for_user(ctx.a.id)

      render_click(ctx.view_a, "p2p_setup_cancel", %{})

      assert p2p_assigns(ctx.view_a) == nil
      refute Lobby.active_session_for_user(ctx.a.id)
      refute render(ctx.view_a) =~ "p2p-setup-form"
    end

    test "PM header exposes the idle P2P entry and opens the creator setup", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgw#{uid()}", "p2pgx#{uid()}")

      render_click(ctx.view_a, "switch_pm", %{"nickname" => ctx.b.nickname})

      html = render(ctx.view_a)
      assert html =~ ~s(data-testid="p2p-peer-entry")
      assert html =~ ~s(data-peer="#{ctx.b.nickname}")
      assert html =~ ~s(data-p2p-state="idle")
      assert html =~ ~s(phx-click="p2p_start_pm_session")
      refute Lobby.active_session_for_user(ctx.a.id)

      render_click(ctx.view_a, "p2p_start_pm_session", %{"peer" => ctx.b.nickname})

      html = render(ctx.view_a)
      assert html =~ "p2p-setup-form"
      assert html =~ "Start P2P Session"
      refute Lobby.active_session_for_user(ctx.a.id)
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

    test "creator sees the P2P console immediately after sending the request", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgc#{uid()}", "p2pgd#{uid()}")
      invite(ctx)

      assert %{state: :invite_sent, role: :creator} = p2p_assigns(ctx.view_a)

      html = render(ctx.view_a)
      assert html =~ "p2p-call-window"
      assert html =~ ~s(data-testid="p2p-session-console")
      assert html =~ ~s(data-p2p-console-section="call")
      assert html =~ ~s(data-testid="p2p-console-nav")
      assert length(Regex.scan(~r/data-testid="p2p-console-nav"/, html)) == 1
      assert length(Regex.scan(~r/data-testid="p2p-call-status-announcer"/, html)) == 1
      assert html =~ "Waiting for peer"
      refute html =~ ~s(data-testid="p2p-webrtc")

      assert has_element?(
               ctx.view_a,
               ~s([data-testid="p2p-call-window"][data-window-initial-open="true"][data-window-default-maximized="true"][data-window-default-x="448"][data-window-default-y="72"][data-window-default-width="640"][data-window-default-height="430"][data-window-min-width="500"][data-window-min-height="320"])
             )

      assert has_element?(
               ctx.view_a,
               ~s([data-testid="p2p-call-taskbar"][data-window-taskbar="p2p-call"]),
               "P2P:"
             )

      render_click(ctx.view_a, "p2p_console_select", %{"section" => "stats"})

      assert p2p_assigns(ctx.view_a).console_section == "stats"
      assert render(ctx.view_a) =~ ~s(data-testid="p2p-console-section-stats")
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

    test "the invited peer joins from the PM header and sees no actionable invite card",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfc#{uid()}", "p2pfd#{uid()}")
      session = invite(ctx)

      flush(ctx.view_b)
      render_click(ctx.view_b, "switch_pm", %{"nickname" => ctx.a.nickname})

      html = render(ctx.view_b)
      assert html =~ ~s(data-testid="p2p-peer-entry")
      assert html =~ ~s(data-p2p-state="pending")
      assert html =~ ~s(data-testid="p2p-peer-join")
      assert html =~ ~s(data-testid="p2p-peer-decline")
      refute html =~ "session-card-accept"
      refute html =~ "session-card-decline"

      assert render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session.token}) =~
               "p2p-setup-dialog"
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

    test "trusted terminal setup loads and saves P2P media preferences", %{conn: conn} do
      previous_turn_listener_count = Application.get_env(:retro_hex_chat, :turn_listener_count)
      Application.put_env(:retro_hex_chat, :turn_listener_count, 1)

      on_exit(fn ->
        Application.put_env(:retro_hex_chat, :turn_listener_count, previous_turn_listener_count)
      end)

      ctx = mount_pair(conn, "p2ptd#{uid()}", "p2pte#{uid()}", trusted_b: true)

      assert :ok =
               TrustedDevices.put_device_preference(
                 ctx.device_b.id,
                 ctx.b.nickname,
                 "p2p_setup",
                 %{
                   "media" => %{"audio" => false, "video" => true},
                   "turn_only" => true,
                   "device_preferences" => %{
                     "audio_input_id" => "stored-mic",
                     "video_input_id" => "stored-cam",
                     "audio_output_id" => "stored-out"
                   }
                 }
               )

      session = invite(ctx)

      render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session.token})
      setup = :sys.get_state(ctx.view_b.pid).socket.assigns.p2p_setup

      refute setup.media.audio
      assert setup.media.video
      assert setup.turn_only

      assert setup.device_preferences == %{
               audio_input_id: "stored-mic",
               video_input_id: "stored-cam",
               audio_output_id: "stored-out"
             }

      render_submit(ctx.view_b, "p2p_setup_accept", %{
        "p2p_setup" => %{
          "audio" => "true",
          "video" => "false",
          "audio_input_id" => "fresh-mic",
          "video_input_id" => "fresh-cam",
          "audio_output_id" => "fresh-out",
          "turn_only" => "false"
        }
      })

      assert TrustedDevices.get_device_preference(ctx.device_b.id, ctx.b.nickname, "p2p_setup") ==
               %{
                 "media" => %{"audio" => true, "video" => false},
                 "turn_only" => false,
                 "device_preferences" => %{
                   "audio_input_id" => "fresh-mic",
                   "video_input_id" => "fresh-cam",
                   "audio_output_id" => "fresh-out"
                 }
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

  describe "P2P console stats section" do
    test "opens via the P2P menu action, shows telemetry, and closes with the session",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfo#{uid()}", "p2pfp#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      # Menu bar / start menu dispatch the same semantic console-selection action.
      render_click(ctx.view_a, "toolbar_action", %{
        "action" => "p2p_console_select",
        "section" => "stats"
      })

      assert p2p_assigns(ctx.view_a).console_section == "stats"
      assert render(ctx.view_a) =~ ~s(data-testid="p2p-console-section-stats")

      # The PM-level session indicator has an explicit Call action.
      render_click(ctx.view_a, "p2p_console_select", %{"section" => "call"})
      assert p2p_assigns(ctx.view_a).console_section == "call"
      connected_html = render(ctx.view_a)
      assert connected_html =~ "p2p-call-window"
      assert length(Regex.scan(~r/data-testid="p2p-console-nav"/, connected_html)) == 1

      assert has_element?(
               ctx.view_a,
               ~s([data-testid="p2p-call-window"][data-window-initial-open="true"][data-window-default-maximized="true"][data-window-default-width="640"][data-window-default-height="430"])
             )

      # A telemetry sample from the WebRTC hook lands normalized in the panel.
      render_click(ctx.view_a, "lobby_stats", %{"connection" => %{"rtt_ms" => 42}})
      assert p2p_assigns(ctx.view_a).stats.connection.rtt_ms == 42

      # Clicking the status-bar area focuses the P2P Session Console (no crash,
      # window stays open).
      render_click(ctx.view_a, "p2p_statusbar_click", %{})
      assert render(ctx.view_a) =~ ~s(data-testid="p2p-session-console")

      # Ending the session tears the window down with it.
      render_click(ctx.view_a, "p2p_statusbar_stop", %{})
      render_click(ctx.view_a, "p2p_confirm_end", %{})
      flush(ctx.view_a)
      assert p2p_assigns(ctx.view_a) == nil
      refute render(ctx.view_a) =~ ~s(data-testid="p2p-session-console")
    end
  end

  describe "P2P console files section" do
    test "mounts with the session, reacts to ft_* events, and feeds the summary",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfq#{uid()}", "p2pfr#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      # The console and file island are always mounted while joined.
      assert render(ctx.view_b) =~ ~s(data-testid="p2p-console-section-files")

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

      assert p2p_assigns(ctx.view_b).console_section == "files"
      assert render(ctx.view_b) =~ "relatorio.pdf"
    end
  end

  describe "call window" do
    test "starting an audio call records media presence and mirrors the summary",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfs#{uid()}", "p2pft#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
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

  describe "P2P console games section" do
    test "a full propose → accept → finish cycle drives both consoles", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfu#{uid()}", "p2pfv#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)
      render_click(ctx.view_a, "lobby_connected", %{})
      flush(ctx.view_b)

      # A proposes; the request opens the Games section on BOTH sides.
      render_click(ctx.view_a, "propose_game", %{"game_id" => "hex_pong"})
      flush(ctx.view_a)
      flush(ctx.view_b)
      assert p2p_assigns(ctx.view_a).console_section == "games"
      assert p2p_assigns(ctx.view_b).console_section == "games"
      assert render(ctx.view_a) =~ ~s(data-testid="p2p-console-section-games")
      assert render(ctx.view_b) =~ ~s(data-testid="p2p-console-section-games")

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
      assert render(ctx.view_a) =~ ~s(data-testid="p2p-console-section-games")

      # Quitting from the console returns the domain to idle without tearing down the session.
      render_click(ctx.view_a, "end_game", %{})
      flush(ctx.view_a)
      assert {:ok, %{game: %{status: "idle"}}} = Lobby.session_info(session.token)
      assert render(ctx.view_a) =~ ~s(data-testid="p2p-session-console")
    end
  end

  describe "P2P console on connect" do
    test "connecting opens the unified session console; ending closes it", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgc#{uid()}", "p2pgd#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(ctx.view_a, "lobby_connected", %{})

      assigns = :sys.get_state(ctx.view_a.pid).socket.assigns
      refute Enum.any?(assigns.open_windows, &String.starts_with?(&1, "p2p-"))

      html = render(ctx.view_a)
      assert html =~ "p2p-call-window"
      assert html =~ ~s(data-testid="p2p-session-console")
      assert p2p_assigns(ctx.view_a).console_section == "call"

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

      # Ending the session tears the console down with it.
      render_click(ctx.view_a, "p2p_statusbar_stop", %{})
      render_click(ctx.view_a, "p2p_confirm_end", %{})
      flush(ctx.view_a)

      html = render(ctx.view_a)
      refute html =~ "p2p-call-window"
      refute html =~ ~s(data-testid="p2p-session-console")
    end

    test "receive-only setup opens the windows but does not auto-start local media",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pgm#{uid()}", "p2pgn#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token, %{"media_mode" => "receive"})
      flush(ctx.view_a)

      render_click(ctx.view_b, "lobby_connected", %{})
      render_click(ctx.view_b, "lobby_media_hook_ready", %{})

      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.peer == %{audio: false, video: false}
      assert p2p_assigns(ctx.view_b).auto_call_started

      render_click(ctx.view_a, "lobby_connected", %{})
      render_click(ctx.view_a, "lobby_media_hook_ready", %{})
      flush(ctx.view_b)

      assert_push_event(ctx.view_b, "lobby_media_join", %{}, @event_timeout)
      refute_push_event(ctx.view_b, "lobby_media_start_video", %{})
      refute_push_event(ctx.view_b, "lobby_media_start_audio", %{})
    end

    test "audio-only setup joins receive-first and starts microphone after peer media",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pga#{uid()}", "p2pgb#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token, %{"audio" => "true", "video" => "false"})
      flush(ctx.view_a)

      render_click(ctx.view_b, "lobby_connected", %{})
      render_click(ctx.view_b, "lobby_media_hook_ready", %{})

      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.peer == %{audio: false, video: false}
      assert p2p_assigns(ctx.view_b).auto_call_started
      assert_push_event(ctx.view_b, "lobby_media_join", %{}, @event_timeout)

      render_click(ctx.view_a, "lobby_connected", %{})
      render_click(ctx.view_a, "lobby_media_hook_ready", %{})
      flush(ctx.view_b)

      assert_push_event(ctx.view_b, "lobby_media_start_audio", %{auto: true}, @event_timeout)
      refute_push_event(ctx.view_b, "lobby_media_start_video", %{})

      render_click(ctx.view_b, "lobby_media_call_started", %{
        "type" => "audio",
        "audio_on" => true,
        "video_on" => false
      })

      flush(ctx.view_b)

      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.peer == %{audio: true, video: false}
    end

    test "connection recovery surfaces retry and restarts both peer hooks", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgy#{uid()}", "p2pgz#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(ctx.view_a, "lobby_webrtc_ready", %{})
      render_click(ctx.view_b, "lobby_webrtc_ready", %{})

      assert_push_event(ctx.view_a, "lobby_start_offer", %{role: "creator"}, @event_timeout)
      assert_push_event(ctx.view_b, "lobby_start_answer", %{role: "peer"}, @event_timeout)

      render_click(ctx.view_a, "lobby_connected", %{})
      render_click(ctx.view_b, "lobby_connected", %{})

      attach_call_telemetry()

      render_click(ctx.view_b, "lobby_media_restart", %{
        "reason" => "audio_only_remote_video_stalled"
      })

      assert_receive {:call_telemetry, event, %{count: 1},
                      %{
                        surface: "p2p",
                        state: "reconnecting",
                        reason: "audio_only_remote_video_stalled",
                        trigger: "media_restart"
                      }}

      assert event == CallEvents.recovery_transition_event()

      assert_push_event(ctx.view_b, "lobby_restart", %{}, @event_timeout)

      assert %{recovery: %{state: :reconnecting, reason: "audio_only_remote_video_stalled"}} =
               p2p_assigns(ctx.view_b)

      flush(ctx.view_a)
      assert_push_event(ctx.view_a, "lobby_restart", %{}, @event_timeout)

      assert %{recovery: %{state: :reconnecting, reason: "audio_only_remote_video_stalled"}} =
               p2p_assigns(ctx.view_a)

      render_click(ctx.view_a, "lobby_connected", %{})
      render_click(ctx.view_b, "lobby_connected", %{})

      render_click(ctx.view_a, "lobby_recovery_pending", %{"reason" => "ice_disconnected"})

      assert_receive {:call_telemetry, ^event, %{count: 1},
                      %{
                        surface: "p2p",
                        state: "reconnecting",
                        reason: "ice_disconnected",
                        trigger: "disconnected"
                      }}

      assert %{
               recovery: %{
                 state: :reconnecting,
                 reason: "ice_disconnected",
                 attempt: nil,
                 manual_retry: false
               }
             } = p2p_assigns(ctx.view_a)

      assert render(ctx.view_a) =~ "Peer media connection was interrupted"

      render_click(ctx.view_a, "lobby_connected", %{})
      assert %{recovery: %{state: :idle}} = p2p_assigns(ctx.view_a)

      render_click(ctx.view_a, "lobby_retry", %{"attempt" => "2", "reason" => "ice_failed"})

      assert %{
               recovery: %{
                 state: :reconnecting,
                 reason: "ice_failed",
                 attempt: 2,
                 manual_retry: false
               }
             } = p2p_assigns(ctx.view_a)

      assert_receive {:call_telemetry, ^event, %{count: 1},
                      %{
                        surface: "p2p",
                        state: "reconnecting",
                        reason: "ice_failed",
                        trigger: "auto",
                        attempt: 2
                      }}

      assert render(ctx.view_a) =~ ~s(data-testid="p2p-recovery-banner")
      assert render(ctx.view_a) =~ "Retrying the peer connection"
      assert render(ctx.view_a) =~ ~s(data-testid="lobby-media-panel")

      render_click(ctx.view_a, "lobby_failed", %{"reason" => "max_retries_exhausted"})

      assert_receive {:call_telemetry, ^event, %{count: 1},
                      %{
                        surface: "p2p",
                        state: "failed",
                        reason: "max_retries_exhausted",
                        manual_retry: true
                      }}

      assert_receive {:call_telemetry, client_error_event, %{count: 1},
                      %{surface: "p2p", code: "max_retries_exhausted", phase: "connection"}}

      assert client_error_event == CallEvents.client_error_event()

      assert %{
               recovery: %{
                 state: :failed,
                 reason: "max_retries_exhausted",
                 manual_retry: true
               }
             } = p2p_assigns(ctx.view_a)

      html = render(ctx.view_a)
      assert html =~ ~s(data-p2p-recovery-state="failed")
      assert html =~ ~s(data-testid="p2p-retry-connection")
      assert html =~ ~s(data-testid="lobby-media-panel")
      failed_message_count = length(Regex.scan(~r/P2P connection failed\./, html))
      assert failed_message_count > 0

      ctx.view_a
      |> element(~s([data-testid="p2p-end-from-recovery"]))
      |> render_click()

      assert render(ctx.view_a) =~ ~s(data-testid="p2p-confirm-dialog")
      render_click(ctx.view_a, "p2p_confirm_cancel", %{})

      render_click(ctx.view_a, "lobby_failed", %{"reason" => "max_retries_exhausted"})

      html = render(ctx.view_a)
      assert html =~ ~s(data-p2p-recovery-state="failed")
      assert length(Regex.scan(~r/P2P connection failed\./, html)) == failed_message_count

      render_click(ctx.view_a, "p2p_retry_connection", %{})

      assert_push_event(ctx.view_a, "lobby_restart", %{}, @event_timeout)

      assert %{recovery: %{state: :reconnecting, reason: "manual_retry"}} =
               p2p_assigns(ctx.view_a)

      flush(ctx.view_b)
      assert_push_event(ctx.view_b, "lobby_restart", %{}, @event_timeout)

      assert %{recovery: %{state: :reconnecting, reason: "peer_manual_retry"}} =
               p2p_assigns(ctx.view_b)

      render_click(ctx.view_a, "lobby_connected", %{})
      assert %{recovery: %{state: :idle}} = p2p_assigns(ctx.view_a)
    end

    test "privacy relay toggle restarts active WebRTC with the current policy", %{conn: conn} do
      ctx = mount_pair(conn, "p2phe#{uid()}", "p2phf#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(ctx.view_a, "lobby_connected", %{})
      render_click(ctx.view_b, "lobby_connected", %{})

      render_click(ctx.view_a, "p2p_toggle_privacy", %{})

      assert %{
               turn_only: true,
               recovery: %{state: :reconnecting, reason: "privacy_changed"}
             } = p2p_assigns(ctx.view_a)

      assert_push_event(
        ctx.view_a,
        "lobby_restart",
        %{role: "creator", turn_only: true},
        @event_timeout
      )

      flush(ctx.view_b)

      assert_push_event(
        ctx.view_b,
        "lobby_restart",
        %{role: "peer", turn_only: false},
        @event_timeout
      )

      assert %{recovery: %{state: :reconnecting, reason: "privacy_changed"}} =
               p2p_assigns(ctx.view_b)
    end

    test "server-side signaling reset restarts active peer hooks", %{conn: conn} do
      ctx = mount_pair(conn, "p2phk#{uid()}", "p2phl#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(ctx.view_a, "lobby_connected", %{})
      render_click(ctx.view_b, "lobby_connected", %{})

      attach_call_telemetry()

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "lobby:#{session.token}", %{
        event: "lobby_start_signaling",
        payload: %{restart: true, reason: "signaling_snapshot_lost"},
        token: session.token
      })

      assert_push_event(
        ctx.view_a,
        "lobby_restart",
        %{role: "creator", reason: "signaling_snapshot_lost"},
        @event_timeout
      )

      assert_push_event(
        ctx.view_b,
        "lobby_restart",
        %{role: "peer", reason: "signaling_snapshot_lost"},
        @event_timeout
      )

      assert %{recovery: %{state: :reconnecting, reason: "signaling_snapshot_lost"}} =
               p2p_assigns(ctx.view_a)

      assert %{recovery: %{state: :reconnecting, reason: "signaling_snapshot_lost"}} =
               p2p_assigns(ctx.view_b)

      assert_receive {:call_telemetry, event, %{count: 1},
                      %{
                        surface: "p2p",
                        state: "reconnecting",
                        reason: "signaling_snapshot_lost",
                        trigger: "server"
                      }}

      assert event == CallEvents.recovery_transition_event()
    end

    test "signal replay request returns stored remote SDP and ICE", %{conn: conn} do
      ctx = mount_pair(conn, "p2phi#{uid()}", "p2phj#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      assert :ok =
               Lobby.record_signaling_event(session.token, ctx.a.id, "lobby_signal", %{
                 type: "offer",
                 sdp: "offer-sdp",
                 epoch: 2,
                 offer_id: "p2p-2-1",
                 from: ctx.a.id
               })

      assert :ok =
               Lobby.record_signaling_event(session.token, ctx.a.id, "lobby_signal", %{
                 type: "ice-candidate",
                 candidate: %{
                   "candidate" => "candidate:1 1 udp 1 127.0.0.1 9 typ host",
                   "sdpMid" => "0"
                 },
                 epoch: 2,
                 from: ctx.a.id
               })

      attach_call_telemetry()

      render_click(ctx.view_b, "lobby_signal_replay_request", %{
        "reason" => "test_replay",
        "epoch" => "2",
        "attempt" => "1"
      })

      assert_receive {:call_telemetry, event, %{count: 1},
                      %{
                        surface: "p2p",
                        action: "served",
                        reason: "test_replay",
                        attempt: 1,
                        event_count: 2
                      }}

      assert event == CallEvents.signaling_replay_event()

      assert_push_event(
        ctx.view_b,
        "lobby_signal_replay",
        %{
          reason: "test_replay",
          request_epoch: 2,
          attempt: 1,
          events: [
            %{event: "lobby_signal", payload: %{type: "offer", replay: true}},
            %{event: "lobby_signal", payload: %{type: "ice-candidate", replay: true}}
          ]
        },
        @event_timeout
      )
    end

    test "rehydrate waits for a stale owner and reattaches when the slot is free",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pha#{uid()}", "p2phb#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)
      flush(ctx.view_b)

      render_click(ctx.view_a, "lobby_connected", %{})
      render_click(ctx.view_b, "lobby_connected", %{})

      Lobby.leave(session.token, ctx.a.id)
      holder = hold_lobby_slot(session.token, ctx.a.id)

      {:ok, reconnect_view, _html} =
        live(chat_conn(conn, ctx.a.nickname, pre_identified: true), "/chat")

      wait_until(fn -> match?(%{reattach_pending: true}, p2p_assigns(reconnect_view)) end)

      assert %{
               token: token,
               reattach_pending: true,
               recovery: %{state: :reconnecting, reason: "reattach_pending"}
             } = p2p_assigns(reconnect_view)

      assert token == session.token
      html = render(reconnect_view)
      assert html =~ "Restoring this P2P session after reconnect."
      refute html =~ "This P2P session is already active in another window."

      render_click(reconnect_view, "lobby_webrtc_ready", %{})
      render_click(ctx.view_b, "lobby_webrtc_ready", %{})
      send(holder, :release)

      assert_push_event(
        reconnect_view,
        "lobby_start_offer",
        %{role: "creator"},
        1_500
      )

      assert %{
               state: :connecting,
               reattach_pending: false,
               recovery: %{state: :reconnecting, reason: "signaling_snapshot_lost"}
             } = p2p_assigns(reconnect_view)
    end

    test "reattach recovery end button can close a session owned by a stale window",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2phc#{uid()}", "p2phd#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(ctx.view_a, "lobby_connected", %{})

      Lobby.leave(session.token, ctx.a.id)
      _holder = hold_lobby_slot(session.token, ctx.a.id)

      {:ok, reconnect_view, _html} =
        live(chat_conn(conn, ctx.a.nickname, pre_identified: true), "/chat")

      # The island publishes the reattach state after the mount patch, so the
      # assertion has to wait for it rather than race it.
      wait_until(fn -> match?(%{reattach_pending: true}, p2p_assigns(reconnect_view)) end)
      assert %{reattach_pending: true} = p2p_assigns(reconnect_view)

      reconnect_view
      |> element(~s([data-testid="p2p-end-from-recovery"]))
      |> render_click()

      assert render(reconnect_view) =~ ~s(data-testid="p2p-confirm-dialog")

      render_click(reconnect_view, "p2p_confirm_end", %{})
      flush(reconnect_view)

      assert {:ok, %{status: "closed", closed_reason: "user_closed"}} =
               Lobby.get_session(session.token)

      assert p2p_assigns(reconnect_view) == nil

      wait_until(fn ->
        flush(ctx.view_b)
        p2p_assigns(ctx.view_b) == nil
      end)
    end

    test "call mini mode and stats section drive the window manager", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgo#{uid()}", "p2pgp#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
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

      render_click(ctx.view_a, "p2p_console_select", %{"section" => "stats"})
      refute p2p_assigns(ctx.view_a).call_mini
      assert p2p_assigns(ctx.view_a).console_section == "stats"
      assert_push_event(ctx.view_a, "window_command", %{action: "open", id: "p2p-call"})

      assert_push_event(ctx.view_a, "window_command", %{
        action: "set_geometry",
        id: "p2p-call",
        width: 640,
        height: 430,
        x: 448,
        y: 72
      })
    end

    test "closing any session window asks to disconnect; confirming ends the session",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pgg#{uid()}", "p2pgh#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
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
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(ctx.view_a, "viewport_info", %{"width" => 390})
      render_click(ctx.view_a, "lobby_connected", %{})

      assigns = :sys.get_state(ctx.view_a.pid).socket.assigns
      refute Enum.any?(assigns.open_windows, &String.starts_with?(&1, "p2p-"))
    end
  end

  describe "PM absorption (p2p_system)" do
    defp p2p_system_messages(nick_a, nick_b) do
      nick_a
      |> ChatQueries.list_private_messages(nick_b)
      |> Map.fetch!(:items)
      |> Enum.filter(&(&1.type == "p2p_system"))
    end

    test "lifecycle notices persist into the PM with a single writer", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfw#{uid()}", "p2pfx#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
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
      assert render(ctx.view_a) =~ ~s(data-testid="p2p-peer-entry")
      assert render(ctx.view_a) =~ ~s(data-testid="pm-p2p-glyph-#{ctx.b.nickname}")
      assert render(ctx.view_a) =~ ~s(data-p2p-state="pending")

      accept_invite(ctx, session.token)
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
      accept_invite(ctx, session.token)
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
      accept_invite(ctx, session_ab.token)
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
      accept_invite(ctx, session_ab.token)
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

  describe "signaling backpressure" do
    test "a rate-limited signal is reported back to the sender", %{conn: conn} do
      ctx = mount_pair(conn, "p2prla#{uid()}", "p2prlb#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)
      limit_all_signals()
      attach_call_telemetry()

      render_click(ctx.view_a, "lobby_signal", %{"type" => "offer", "sdp" => "offer-sdp"})

      assert_push_event(
        ctx.view_a,
        "lobby_signal_rejected",
        %{code: "rate_limited", phase: "signal", retry_after_ms: 4_200},
        @event_timeout
      )

      assert_receive {:call_telemetry, event, %{count: 1},
                      %{surface: "p2p", code: "rate_limited", phase: "signal"}}

      assert event == CallEvents.client_error_event()
    end

    test "a rate-limited renegotiation request is reported back to the sender", %{conn: conn} do
      ctx = mount_pair(conn, "p2prlc#{uid()}", "p2prld#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_b)
      limit_all_signals()

      render_click(ctx.view_b, "lobby_renegotiate", %{"kinds" => ["audio"]})

      assert_push_event(
        ctx.view_b,
        "lobby_signal_rejected",
        %{code: "rate_limited", phase: "renegotiate", retry_after_ms: 4_200},
        @event_timeout
      )
    end
  end
end
