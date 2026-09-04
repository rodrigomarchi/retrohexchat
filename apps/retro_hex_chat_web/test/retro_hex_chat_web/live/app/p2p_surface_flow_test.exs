defmodule RetroHexChatWeb.App.P2PSurfaceFlowTest do
  @moduledoc """
  Being inside a P2P session, which happens at `/p2p/:token` and nowhere else.

  These flows used to be driven through the chat's P2P window. There is no such
  window: a session has one door and it is the card the invite writes into the
  private message. So each test here does both halves — the chat's control sends
  the invite and creates the session, and the test follows the address that card
  carries, the way a reader does.

  What the chat still draws *about* a session it cannot reach — the PM badge, the
  tab glyph, the status zone — is asserted in `chat_live/p2p_session_flow_test.exs`.

  Asserts on synchronous LiveView state (`:sys.get_state`) and persisted domain
  rows — never on async stream diffs.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Calls.Events, as: CallEvents
  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.RegisteredNick

  # How long a pushed event may take to arrive, not how long it should. The
  # assertion returns the moment the event lands, so a generous bound costs
  # nothing on an idle machine and stops `make ci` — several partitions at once
  # — from failing on whichever test happened to be waiting when the box was
  # busy.
  @event_timeout 5_000

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

    conn_a = chat_conn(conn, nick_a, chat_conn_opts(trusted_a))
    conn_b = chat_conn(conn, nick_b, chat_conn_opts(trusted_b))

    {:ok, view_a, _} = live(conn_a, "/chat")
    {:ok, view_b, _} = live(conn_b, "/chat")

    Process.put({:conn, view_a.pid}, conn_a)
    Process.put({:conn, view_b.pid}, conn_b)

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

  # The session is a LiveView of its own, with no parent and no window in the
  # chat. A test opens it the way a person does: by following the address the
  # invite card carries. Two independent LiveViews, so the test remembers which
  # session it opened for which chat instead of looking for a child that does
  # not exist.
  defp open_p2p(view, token) do
    {:ok, p2p, _html} = live(Process.get({:conn, view.pid}), "/p2p/#{token}")
    Process.put({:p2p_view, view.pid}, p2p)
    flush(view)
    p2p
  end

  defp p2p_view(view) do
    case Process.get({:p2p_view, view.pid}) do
      nil ->
        nil

      p2p ->
        # Twice: the first round makes the session handle the control, and the
        # `send_update` that control issues is only in its mailbox after that.
        :sys.get_state(p2p.pid)
        :sys.get_state(p2p.pid)
        p2p
    end
  catch
    :exit, _gone -> nil
  end

  defp p2p_html(view) do
    case p2p_view(view) do
      nil -> ""
      p2p -> render(p2p)
    end
  catch
    :exit, _gone -> ""
  end

  # A session that has left its page holds nothing, which is the same answer as
  # never having opened one.
  defp p2p_assigns(view) do
    case p2p_view(view) do
      nil -> nil
      p2p -> :sys.get_state(p2p.pid).socket.assigns.p2p_session
    end
  catch
    :exit, _gone -> nil
  end

  # Both processes: a control on the session does not reach the chat, and a chat
  # control does not reach the session, so neither is settled by the other.
  defp flush(view) do
    state = :sys.get_state(view.pid)
    settle_p2p(Process.get({:p2p_view, view.pid}))
    state
  end

  defp settle_p2p(nil), do: :ok

  defp settle_p2p(p2p) do
    :sys.get_state(p2p.pid)
  catch
    :exit, _gone -> :ok
  end

  @setup_defaults %{"audio" => "true", "video" => "true", "turn_only" => "false"}

  # `[Ready]` is two halves: the devices, submitted here, and the WebRTC hook
  # reporting that it is listening — which no ExUnit test has, so it is played
  # by hand. Only both together let the domain's gate fire.
  defp ready(view, params) do
    child = p2p_view(view)
    render_submit(child, "p2p_room_ready", %{"p2p_setup" => Map.merge(@setup_defaults, params)})
    render_click(child, "lobby_webrtc_ready", %{})
    flush(view)
    child
  end

  defp start_session(view) do
    render_click(p2p_view(view), "p2p_room_start", %{})
    flush(view)
  end

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

  # Creating the session IS inviting, so `/p2p <nick>` sends the invite and the
  # creator lands in the starting room — where the devices are chosen while
  # waiting for an answer, instead of before asking the question.
  defp invite(ctx, params \\ %{}) do
    submit_command_sync(ctx.view_a, "/p2p #{ctx.b.nickname}")

    session = Lobby.active_session_for_user(ctx.a.id)
    assert session, "expected /p2p to create the session and send the invite"

    on_exit(fn -> stop_session_server(session.token) end)

    # The creator enters by the same door as everybody else: the card the invite
    # just wrote into the conversation.
    open_p2p(ctx.view_a, session.token)
    ready(ctx.view_a, params)

    session
  end

  defp accept_invite(target, token, params \\ %{})

  defp accept_invite(%{view_a: creator_view, view_b: peer_view}, token, params) do
    accept_invite(peer_view, token, params)
    sync_lobby_join(creator_view, token)
    # Both are ready by now, so the host's `[Start]` is what releases the first
    # offer — the rule the moduledoc has always stated, with a button on it.
    start_session(creator_view)
    flush(peer_view)
  end

  defp accept_invite(view, token, params) do
    open_p2p(view, token)
    ready(view, params)
  end

  # Both slots are filled by the time this returns, and nothing here waits for
  # them. The peer's submit calls `Lobby.join_session/2` inside its own
  # `handle_event`, and the session server broadcasts `lobby_peer_joined`
  # *before* replying to it — so when `render_submit/3` comes back, that message
  # is already sitting in the creator's mailbox. The creator joins from inside
  # the handler for it, synchronously, with no island hop in between; draining
  # its mailbox is therefore the whole synchronisation.
  #
  # Polling with a sleep budget stands in for this badly: a budget is a guess
  # about how loaded the machine is, and at 500ms it fails under `make ci`
  # while passing everywhere else. What is asserted here cannot be a matter of
  # timing, so the failure prints what the session actually says instead of
  # reporting that it ran out of patience.
  defp sync_lobby_join(view, token) do
    flush(view)

    case Lobby.session_info(token) do
      {:ok, %{creator_joined: true, peer_joined: true, session: %{status: status}}}
      when status in ["lobby", "connected"] ->
        :ok

      other ->
        flunk("""
        expected P2P session #{token} to have both participants in the lobby.

        Lobby.session_info/1 returned:

        #{inspect(other, pretty: true, limit: :infinity)}

        The row behind it says:

        #{inspect(session_row(token), pretty: true, limit: :infinity)}
        """)
    end
  end

  # `session_info/1` answers from the process, so `{:error, :not_found}` only
  # says the process is gone — not whether it was never started, expired on a
  # timeout, or was closed. The row records which, and the row outlives the
  # process, so it is what turns this failure into a diagnosis.
  defp session_row(token) do
    case RetroHexChat.Lobby.Queries.get_session_by_token(token) do
      nil -> :no_row
      session -> Map.take(session, [:status, :closed_reason, :closed_at, :updated_at])
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
    test "the invite goes out with the command and the creator lands in the room",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pgs#{uid()}", "p2pgt#{uid()}")

      submit_command_sync(ctx.view_a, "/p2p #{ctx.b.nickname}")

      # Creating the session IS inviting, so the question is asked first and the
      # devices are chosen while waiting for the answer.
      session = Lobby.active_session_for_user(ctx.a.id)
      assert session
      on_exit(fn -> stop_session_server(session.token) end)

      # The chat did not put anybody anywhere: the creator follows the card,
      # like the person who was invited.
      html = render(open_p2p(ctx.view_a, session.token))
      assert html =~ ~s(data-testid="p2p-starting-room")
      assert html =~ "p2p-setup-form"
      assert html =~ "In the room"
      assert %{state: :invite_sent, role: :creator, room_ready: false} = p2p_assigns(ctx.view_a)

      # Nothing is armed before `[Ready]`: a hook mounted here would report
      # readiness for devices nobody has chosen.
      refute html =~ ~s(data-testid="p2p-webrtc")
    end

    test "the PM entry creates the session, and its address is the way in", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgw#{uid()}", "p2pgx#{uid()}")

      render_click(ctx.view_a, "switch_pm", %{"nickname" => ctx.b.nickname})
      refute Lobby.active_session_for_user(ctx.a.id)

      render_click(ctx.view_a, "p2p_start_pm_session", %{"peer" => ctx.b.nickname})

      session = Lobby.active_session_for_user(ctx.a.id)
      assert session
      on_exit(fn -> stop_session_server(session.token) end)

      html = render(open_p2p(ctx.view_a, session.token))
      assert html =~ ~s(data-testid="p2p-starting-room")
      assert html =~ "p2p-setup-form"
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

      html = p2p_html(ctx.view_a)
      assert html =~ "p2p-call-window"
      assert html =~ ~s(data-testid="p2p-starting-room")
      assert html =~ ~s(data-testid="p2p-room-roster")
      # The one sentence the old screen never said out loud.
      assert html =~ "Waiting for #{ctx.b.nickname} to accept the invite."
      # `[Ready]` was pressed by `invite/2`, so the anchor is up and the hook is
      # listening; the console is still behind the host's `[Start]`.
      assert html =~ ~s(data-testid="p2p-webrtc")
      refute html =~ ~s(data-testid="p2p-session-console")

      assert has_element?(p2p_view(ctx.view_a), ~s([data-testid="p2p-room-start"]))
    end

    test "creator holds :invite_sent and the peer's accept joins both", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfa#{uid()}", "p2pfb#{uid()}")
      session = invite(ctx)

      assert %{state: :invite_sent, role: :creator} = p2p_assigns(ctx.view_a)

      html = render(open_p2p(ctx.view_b, session.token))
      assert html =~ ~s(data-testid="p2p-starting-room")

      ready(ctx.view_b, %{"audio" => "true", "video" => "false"})

      assert %{state: :joining, role: :peer} = p2p_assigns(ctx.view_b)
      assert p2p_assigns(ctx.view_b).media_mode == "audio"

      # The creator joins on the peer's lobby_peer_joined (subscribe-only
      # until then, so the standalone page can still claim the session);
      # only after that do BOTH count as joined and the status flips.
      flush(ctx.view_a)
      assert %{state: :joining} = p2p_assigns(ctx.view_a)
      assert {:ok, %{status: "lobby"}} = Lobby.get_session(session.token)
    end

    test "the invited peer arrives at the room by following the invite's address",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfc#{uid()}", "p2pfd#{uid()}")
      session = invite(ctx)

      flush(ctx.view_b)

      assert render(open_p2p(ctx.view_b, session.token)) =~
               ~s(data-testid="p2p-starting-room")
    end

    test "accepting takes the seat and stops at the room until Ready", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgk#{uid()}", "p2pgl#{uid()}")
      session = invite(ctx)

      html = render(open_p2p(ctx.view_b, session.token))
      assert html =~ ~s(data-testid="p2p-starting-room")

      # Arriving is consent, so the seat is taken — but nothing is armed and no
      # offer can be released until both sides say they are ready.
      assert %{state: :joining, role: :peer, room_ready: false} = p2p_assigns(ctx.view_b)
      refute p2p_html(ctx.view_b) =~ ~s(data-testid="p2p-webrtc")
      refute p2p_html(ctx.view_b) =~ ~s(data-testid="p2p-session-console")
      assert {:ok, %{status: "lobby"}} = Lobby.get_session(session.token)
    end

    test "setup checkboxes and devices seed the P2P media defaults", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgq#{uid()}", "p2pgr#{uid()}")
      session = invite(ctx)

      open_p2p(ctx.view_b, session.token)

      ready(ctx.view_b, %{
        "audio" => "true",
        "video" => "false",
        "audio_input_id" => "mic-1",
        "video_input_id" => "cam-1",
        "audio_output_id" => "out-1"
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

      open_p2p(ctx.view_b, session.token)
      setup = :sys.get_state(p2p_view(ctx.view_b).pid).socket.assigns.setup

      refute setup.media.audio
      assert setup.media.video
      assert setup.turn_only

      assert setup.device_preferences == %{
               audio_input_id: "stored-mic",
               video_input_id: "stored-cam",
               audio_output_id: "stored-out"
             }

      ready(ctx.view_b, %{
        "audio" => "true",
        "video" => "false",
        "audio_input_id" => "fresh-mic",
        "video_input_id" => "fresh-cam",
        "audio_output_id" => "fresh-out"
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
      refute p2p_html(ctx.view_a) =~ "status-bar-p2p"
    end

    test "the creator cancels a pending invite from the status bar", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfg#{uid()}", "p2pfh#{uid()}")
      session = invite(ctx)

      render_click(p2p_view(ctx.view_a), "p2p_end_session", %{})
      p2p_view(ctx.view_a)

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

      render_click(p2p_view(ctx.view_a), "p2p_console_select", %{"section" => "stats"})

      assert p2p_assigns(ctx.view_a).console_section == "stats"
      assert p2p_html(ctx.view_a) =~ ~s(data-testid="p2p-console-section-stats")

      # The PM-level session indicator has an explicit Call action.
      render_click(p2p_view(ctx.view_a), "p2p_console_select", %{"section" => "call"})
      assert p2p_assigns(ctx.view_a).console_section == "call"
      connected_html = p2p_html(ctx.view_a)
      assert connected_html =~ "p2p-call-window"
      assert length(Regex.scan(~r/data-testid="p2p-console-nav"/, connected_html)) == 1

      assert has_element?(
               p2p_view(ctx.view_a),
               ~s([data-testid="p2p-call-window"][data-window-initial-open="true"][data-window-default-maximized="true"])
             )

      # A telemetry sample from the WebRTC hook lands normalized in the panel.
      render_click(p2p_view(ctx.view_a), "lobby_stats", %{"connection" => %{"rtt_ms" => 42}})
      assert p2p_assigns(ctx.view_a).stats.connection.rtt_ms == 42

      assert p2p_html(ctx.view_a) =~ ~s(data-testid="p2p-session-console")

      # Ending the session tears the window down with it.
      render_click(p2p_view(ctx.view_a), "p2p_end_session", %{})
      render_click(p2p_view(ctx.view_a), "p2p_confirm_end", %{})
      flush(ctx.view_a)
      assert p2p_assigns(ctx.view_a) == nil
      refute p2p_html(ctx.view_a) =~ ~s(data-testid="p2p-session-console")
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
      assert p2p_html(ctx.view_b) =~ ~s(data-testid="p2p-console-section-files")

      # The WebRTC hook reports the link up; the panel unlocks on :connected.
      render_click(p2p_view(ctx.view_b), "lobby_connected", %{})
      assert %{state: :connected} = p2p_assigns(ctx.view_b)

      # An incoming offer flows hook → host adapter → island, opens the
      # window and mirrors the C2 summary up to the host.
      render_click(p2p_view(ctx.view_b), "file_transfer_ready", %{})

      render_click(p2p_view(ctx.view_b), "ft_offer_received", %{
        "file_name" => "relatorio.pdf",
        "formatted_size" => "1.2 MB"
      })

      flush(ctx.view_b)

      assert %{file_summary: %{status: "offer_received", file_name: "relatorio.pdf"}} =
               p2p_assigns(ctx.view_b)

      assert p2p_assigns(ctx.view_b).console_section == "files"
      assert p2p_html(ctx.view_b) =~ "relatorio.pdf"
    end
  end

  describe "call window" do
    test "starting an audio call records media presence and mirrors the summary",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfs#{uid()}", "p2pft#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)
      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})

      assert p2p_html(ctx.view_a) =~ "p2p-call-window"

      # The button in the call panel → island → domain records this peer's
      # media presence. Driven by the event the panel really pushes, so a
      # control that stops reaching this path takes the test down with it.
      render_click(p2p_view(ctx.view_a), "start_call", %{"type" => "audio"})
      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.creator == %{audio: true, video: false}

      # The media hook echoes the call start; the C2 summary reaches the host.
      render_click(p2p_view(ctx.view_a), "lobby_media_call_started", %{"type" => "audio"})
      flush(ctx.view_a)
      assert %{call_summary: %{type: "audio"}} = p2p_assigns(ctx.view_a)

      # Ending the call clears the summary and the media presence.
      render_click(p2p_view(ctx.view_a), "lobby_media_call_ended", %{})
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
      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      flush(ctx.view_b)

      # A proposes; the request opens the Games section on BOTH sides.
      render_click(p2p_view(ctx.view_a), "propose_game", %{"game_id" => "hex_pong"})
      flush(ctx.view_a)
      flush(ctx.view_b)
      assert p2p_assigns(ctx.view_a).console_section == "games"
      assert p2p_assigns(ctx.view_b).console_section == "games"
      assert p2p_html(ctx.view_a) =~ ~s(data-testid="p2p-console-section-games")
      assert p2p_html(ctx.view_b) =~ ~s(data-testid="p2p-console-section-games")

      # B accepts: the game starts and the C2 summary flags it active.
      render_click(p2p_view(ctx.view_b), "respond_game", %{"accepted" => "true"})
      flush(ctx.view_a)
      flush(ctx.view_b)
      assert {:ok, %{game: %{status: "playing"}}} = Lobby.session_info(session.token)
      assert %{game_summary: %{active?: true}} = p2p_assigns(ctx.view_a)

      # The host reports the authoritative result; both islands show it and
      # the session stays connected.
      render_click(p2p_view(ctx.view_a), "lobby_game_result", %{
        "score" => %{"p1" => 5, "p2" => 3},
        "winner" => 1
      })

      flush(ctx.view_a)
      assert {:ok, %{game: %{status: "finished"}}} = Lobby.session_info(session.token)
      assert p2p_html(ctx.view_a) =~ ~s(data-testid="p2p-console-section-games")

      # Quitting from the console returns the domain to idle without tearing down the session.
      render_click(p2p_view(ctx.view_a), "end_game", %{})
      flush(ctx.view_a)
      assert {:ok, %{game: %{status: "idle"}}} = Lobby.session_info(session.token)
      assert p2p_html(ctx.view_a) =~ ~s(data-testid="p2p-session-console")
    end
  end

  describe "P2P console on connect" do
    test "connecting opens the unified session console; ending closes it", %{conn: conn} do
      ctx = mount_pair(conn, "p2pgc#{uid()}", "p2pgd#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})

      html = p2p_html(ctx.view_a)
      assert html =~ "p2p-call-window"
      assert html =~ ~s(data-testid="p2p-session-console")
      assert p2p_assigns(ctx.view_a).console_section == "call"

      # Once the media hook reports ready, the call auto-starts (mic+camera)
      # exactly once — media presence lands in the domain.
      render_click(p2p_view(ctx.view_a), "lobby_media_hook_ready", %{})
      flush(ctx.view_a)
      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.creator == %{audio: true, video: true}
      assert p2p_assigns(ctx.view_a).auto_call_started

      # A second ready report (hook re-mount) must not restart the call.
      render_click(p2p_view(ctx.view_a), "lobby_media_hook_ready", %{})
      assert p2p_assigns(ctx.view_a).auto_call_started

      # Ending the session tears the console down with it.
      render_click(p2p_view(ctx.view_a), "p2p_end_session", %{})
      render_click(p2p_view(ctx.view_a), "p2p_confirm_end", %{})
      flush(ctx.view_a)

      html = p2p_html(ctx.view_a)
      refute html =~ ~s(data-testid="p2p-session-console")
    end

    test "receive-only setup opens the windows but does not auto-start local media",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pgm#{uid()}", "p2pgn#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token, %{"media_mode" => "receive"})
      flush(ctx.view_a)

      render_click(p2p_view(ctx.view_b), "lobby_connected", %{})
      render_click(p2p_view(ctx.view_b), "lobby_media_hook_ready", %{})

      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.peer == %{audio: false, video: false}
      assert p2p_assigns(ctx.view_b).auto_call_started

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      render_click(p2p_view(ctx.view_a), "lobby_media_hook_ready", %{})
      flush(ctx.view_b)

      assert_push_event(p2p_view(ctx.view_b), "lobby_media_join", %{}, @event_timeout)
      refute_push_event(p2p_view(ctx.view_b), "lobby_media_start_video", %{})
      refute_push_event(p2p_view(ctx.view_b), "lobby_media_start_audio", %{})
    end

    test "audio-only setup joins receive-first and starts microphone after peer media",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pga#{uid()}", "p2pgb#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token, %{"audio" => "true", "video" => "false"})
      flush(ctx.view_a)

      render_click(p2p_view(ctx.view_b), "lobby_connected", %{})
      render_click(p2p_view(ctx.view_b), "lobby_media_hook_ready", %{})

      {:ok, state} = Lobby.session_info(session.token)
      assert state.media.peer == %{audio: false, video: false}
      assert p2p_assigns(ctx.view_b).auto_call_started
      assert_push_event(p2p_view(ctx.view_b), "lobby_media_join", %{}, @event_timeout)

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      render_click(p2p_view(ctx.view_a), "lobby_media_hook_ready", %{})
      flush(ctx.view_b)

      assert_push_event(
        p2p_view(ctx.view_b),
        "lobby_media_start_audio",
        %{auto: true},
        @event_timeout
      )

      refute_push_event(p2p_view(ctx.view_b), "lobby_media_start_video", %{})

      render_click(p2p_view(ctx.view_b), "lobby_media_call_started", %{
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

      render_click(p2p_view(ctx.view_a), "lobby_webrtc_ready", %{})
      render_click(p2p_view(ctx.view_b), "lobby_webrtc_ready", %{})

      assert_push_event(
        p2p_view(ctx.view_a),
        "lobby_start_offer",
        %{role: "creator"},
        @event_timeout
      )

      assert_push_event(
        p2p_view(ctx.view_b),
        "lobby_start_answer",
        %{role: "peer"},
        @event_timeout
      )

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      render_click(p2p_view(ctx.view_b), "lobby_connected", %{})

      attach_call_telemetry()

      render_click(p2p_view(ctx.view_b), "lobby_media_restart", %{
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

      assert_push_event(p2p_view(ctx.view_b), "lobby_restart", %{}, @event_timeout)

      assert %{recovery: %{state: :reconnecting, reason: "audio_only_remote_video_stalled"}} =
               p2p_assigns(ctx.view_b)

      flush(ctx.view_a)
      assert_push_event(p2p_view(ctx.view_a), "lobby_restart", %{}, @event_timeout)

      assert %{recovery: %{state: :reconnecting, reason: "audio_only_remote_video_stalled"}} =
               p2p_assigns(ctx.view_a)

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      render_click(p2p_view(ctx.view_b), "lobby_connected", %{})

      render_click(p2p_view(ctx.view_a), "lobby_recovery_pending", %{
        "reason" => "ice_disconnected"
      })

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

      assert p2p_html(ctx.view_a) =~ "Peer media connection was interrupted"

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      assert %{recovery: %{state: :idle}} = p2p_assigns(ctx.view_a)

      render_click(p2p_view(ctx.view_a), "lobby_retry", %{
        "attempt" => "2",
        "reason" => "ice_failed"
      })

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

      assert p2p_html(ctx.view_a) =~ ~s(data-testid="p2p-recovery-banner")
      assert p2p_html(ctx.view_a) =~ "Retrying the peer connection"
      assert p2p_html(ctx.view_a) =~ ~s(data-testid="lobby-media-panel")

      render_click(p2p_view(ctx.view_a), "lobby_failed", %{"reason" => "max_retries_exhausted"})

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

      html = p2p_html(ctx.view_a)
      assert html =~ ~s(data-p2p-recovery-state="failed")
      assert html =~ ~s(data-testid="p2p-retry-connection")
      assert html =~ ~s(data-testid="lobby-media-panel")
      failed_message_count = length(Regex.scan(~r/P2P connection failed\./, html))
      assert failed_message_count > 0

      ctx.view_a
      |> p2p_view()
      |> element(~s([data-testid="p2p-end-from-recovery"]))
      |> render_click()

      assert has_element?(p2p_view(ctx.view_a), "#p2p-confirm-dialog-show-trigger")

      render_click(p2p_view(ctx.view_a), "p2p_confirm_cancel", %{})

      render_click(p2p_view(ctx.view_a), "lobby_failed", %{"reason" => "max_retries_exhausted"})

      html = p2p_html(ctx.view_a)
      assert html =~ ~s(data-p2p-recovery-state="failed")
      assert length(Regex.scan(~r/P2P connection failed\./, html)) == failed_message_count

      render_click(p2p_view(ctx.view_a), "p2p_retry_connection", %{})

      assert_push_event(p2p_view(ctx.view_a), "lobby_restart", %{}, @event_timeout)

      assert %{recovery: %{state: :reconnecting, reason: "manual_retry"}} =
               p2p_assigns(ctx.view_a)

      flush(ctx.view_b)
      assert_push_event(p2p_view(ctx.view_b), "lobby_restart", %{}, @event_timeout)

      assert %{recovery: %{state: :reconnecting, reason: "peer_manual_retry"}} =
               p2p_assigns(ctx.view_b)

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      assert %{recovery: %{state: :idle}} = p2p_assigns(ctx.view_a)
    end

    test "server-side signaling reset restarts active peer hooks", %{conn: conn} do
      ctx = mount_pair(conn, "p2phk#{uid()}", "p2phl#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      render_click(p2p_view(ctx.view_b), "lobby_connected", %{})

      attach_call_telemetry()

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "lobby:#{session.token}", %{
        event: "lobby_start_signaling",
        payload: %{restart: true, reason: "signaling_snapshot_lost"},
        token: session.token
      })

      assert_push_event(
        p2p_view(ctx.view_a),
        "lobby_restart",
        %{role: "creator", reason: "signaling_snapshot_lost"},
        @event_timeout
      )

      assert_push_event(
        p2p_view(ctx.view_b),
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

    test "a second window of the same person takes the session over", %{conn: conn} do
      ctx = mount_pair(conn, "p2pha#{uid()}", "p2phb#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)
      flush(ctx.view_b)

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      render_click(p2p_view(ctx.view_b), "lobby_connected", %{})

      first = p2p_view(ctx.view_a)

      # The same session, open at its own address in another tab. A second chat
      # would end the first outright (that is the chat's own takeover); the P2P
      # surface never announces one, which is exactly why two of them can be
      # asked for the same seat.
      {:ok, second, _html} =
        build_conn()
        |> chat_conn(ctx.a.nickname, pre_identified: true)
        |> live(~p"/p2p/#{session.token}")

      # Opening the session somewhere else is a takeover, not a refusal: one
      # person is one participant, and the media belongs to the page they are
      # looking at. Refusing means five backoff attempts and then "close that
      # other window" — a dead end reached by doing something reasonable.
      assert %{token: token, displaced: false} =
               :sys.get_state(second.pid).socket.assigns.p2p_session

      assert token == session.token

      # The page that lost the seat says so, and offers the way back rather
      # than an error.
      :sys.get_state(first.pid)
      assert %{displaced: true} = p2p_assigns(ctx.view_a)
      html = p2p_html(ctx.view_a)
      assert html =~ ~s(data-testid="p2p-displaced")
      assert html =~ ~s(data-testid="p2p-reclaim")
      # The anchor is gone with the seat, so the hook is destroyed and this
      # browser's peer connection goes down with it.
      refute html =~ ~s(data-testid="p2p-webrtc")

      # And the domain rebuilt the link for the page that now holds it: the
      # takeover releases the seat exactly the way a disconnect does, so the
      # gate that re-signals after a dropped socket re-signals here too.
      render_submit(second, "p2p_room_ready", %{"p2p_setup" => @setup_defaults})
      render_click(second, "lobby_webrtc_ready", %{})

      assert_push_event(second, "lobby_start_offer", %{role: "creator"}, @event_timeout)
    end

    test "the displaced window can take the session back", %{conn: conn} do
      ctx = mount_pair(conn, "p2phc#{uid()}", "p2phd#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})

      first = p2p_view(ctx.view_a)

      {:ok, second, _html} =
        build_conn()
        |> chat_conn(ctx.a.nickname, pre_identified: true)
        |> live(~p"/p2p/#{session.token}")

      :sys.get_state(first.pid)
      assert %{displaced: true} = p2p_assigns(ctx.view_a)

      render_click(first, "p2p_room_reclaim", %{})

      assert %{displaced: false} = p2p_assigns(ctx.view_a)
      :sys.get_state(second.pid)
      assert %{displaced: true} = :sys.get_state(second.pid).socket.assigns.p2p_session
    end

    # The X asks rather than acts, and asking must not take the connection down
    # with the question: the anchor is what the media, file and game hooks find
    # the shared peer connection through.
    test "ending asks, and the session survives the question", %{conn: conn} do
      ctx = mount_pair(conn, "p2pwc#{uid()}", "p2pwd#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)
      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})

      render_click(p2p_view(ctx.view_a), "p2p_end_session", %{})

      assert has_element?(p2p_view(ctx.view_a), "#p2p-confirm-dialog-show-trigger")
      assert has_element?(p2p_view(ctx.view_a), ~s([data-testid="p2p-webrtc"]))
      assert %{state: :connected} = p2p_assigns(ctx.view_a)
      assert {:ok, %{status: "connected"}} = Lobby.get_session(session.token)

      render_click(p2p_view(ctx.view_a), "p2p_confirm_cancel", %{})

      refute has_element?(p2p_view(ctx.view_a), "#p2p-confirm-dialog-show-trigger")
      assert has_element?(p2p_view(ctx.view_a), ~s([data-testid="p2p-webrtc"]))
      assert {:ok, %{status: "connected"}} = Lobby.get_session(session.token)
    end

    test "ending from a window that holds the seat closes the session", %{conn: conn} do
      ctx = mount_pair(conn, "p2phe#{uid()}", "p2phf#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})

      render_click(p2p_view(ctx.view_a), "p2p_end_session", %{})

      # The dialog's markup is always in the document; what is asserted is
      # that it is *showing*, which is the only part a person can act on. The
      # show trigger only exists while it is open.
      assert has_element?(p2p_view(ctx.view_a), "#p2p-confirm-dialog-show-trigger")

      render_click(p2p_view(ctx.view_a), "p2p_confirm_end", %{})
      p2p_view(ctx.view_a)

      assert {:ok, %{status: "closed", closed_reason: "user_closed"}} =
               Lobby.get_session(session.token)

      wait_until(fn ->
        flush(ctx.view_a)
        p2p_assigns(ctx.view_a) == nil
      end)

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
      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})

      render_click(p2p_view(ctx.view_a), "p2p_toggle_call_mini", %{})
      assert p2p_assigns(ctx.view_a).call_mini

      assert_push_event(p2p_view(ctx.view_a), "window_command", %{
        action: "set_geometry",
        id: "p2p-call",
        width: 300,
        height: 236,
        anchor: "bottom_right"
      })

      assert p2p_html(ctx.view_a) =~ ~s(data-call-mini="true")

      render_click(p2p_view(ctx.view_a), "p2p_console_select", %{"section" => "stats"})
      refute p2p_assigns(ctx.view_a).call_mini
      assert p2p_assigns(ctx.view_a).console_section == "stats"

      assert_push_event(p2p_view(ctx.view_a), "window_command", %{
        action: "set_geometry",
        id: "p2p-call",
        width: 640,
        height: 430,
        x: 448,
        y: 72
      })
    end

    test "ending asks first; confirming ends the session",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pgg#{uid()}", "p2pgh#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)
      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})

      # End routes to the confirm — nothing ends yet.
      render_click(p2p_view(ctx.view_a), "p2p_end_session", %{})
      assert {:ok, %{status: "connected"}} = Lobby.get_session(session.token)
      assert %{state: :connected} = p2p_assigns(ctx.view_a)

      # Confirming the dialog disconnects the whole session.
      render_click(p2p_view(ctx.view_a), "p2p_confirm_end", %{})
      flush(ctx.view_a)
      assert {:ok, %{status: "closed"}} = Lobby.get_session(session.token)
      assert p2p_assigns(ctx.view_a) == nil
      refute p2p_html(ctx.view_a) =~ ~s(data-testid="p2p-session-console")
    end

    test "the burst is skipped on a mobile viewport", %{conn: conn} do
      ctx = mount_pair(conn, "p2pge#{uid()}", "p2pgf#{uid()}")
      session = invite(ctx)
      accept_invite(ctx, session.token)
      flush(ctx.view_a)

      render_click(p2p_view(ctx.view_a), "viewport_info", %{"width" => 390})
      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})

      refute_push_event(p2p_view(ctx.view_a), "window_command", %{action: "open"})
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
      render_click(p2p_view(ctx.view_a), "lobby_connected", %{})
      render_click(p2p_view(ctx.view_b), "lobby_connected", %{})
      flush(ctx.view_a)
      flush(ctx.view_b)

      assert [connected_msg] = p2p_system_messages(ctx.a.nickname, ctx.b.nickname)
      assert connected_msg.content =~ "connected"

      # Ending persists exactly one more line, written by the ender.
      render_click(p2p_view(ctx.view_a), "p2p_end_session", %{})
      render_click(p2p_view(ctx.view_a), "p2p_confirm_end", %{})
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
    end
  end

  # A person can be in more than one session at once, each with a different
  # peer and each in a tab of its own, so there is no switch to confirm.
  # "One session at a time" is a property of the single window a chat renders
  # them in, not of the domain.
  describe "more than one session" do
    test "a second peer's invite creates a second session, and neither ends the other",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfi#{uid()}", "p2pfj#{uid()}")
      c = register("p2pfk#{uid()}")
      conn_c = chat_conn(conn, c.nickname, pre_identified: true)
      {:ok, view_c, _} = live(conn_c, "/chat")
      Process.put({:conn, view_c.pid}, conn_c)

      session_ab = invite(ctx)
      accept_invite(ctx, session_ab.token)
      flush(ctx.view_a)

      submit_command_sync(view_c, "/p2p #{ctx.b.nickname}")
      session_cb = Lobby.active_session_for_user(c.id)
      assert session_cb
      on_exit(fn -> stop_session_server(session_cb.token) end)

      assert {:ok, %{status: "lobby"}} = Lobby.get_session(session_ab.token)
      assert {:ok, %{status: "pending"}} = Lobby.get_session(session_cb.token)

      # B is a badge for each of them, and the two are separate rooms.
      flush(ctx.view_b)
      sessions = :sys.get_state(ctx.view_b.pid).socket.assigns.p2p_pm_sessions
      assert map_size(sessions) == 2
      assert sessions[String.downcase(ctx.a.nickname)].token == session_ab.token
      assert sessions[String.downcase(c.nickname)].token == session_cb.token
    end
  end

  # The signaling backpressure tests moved to `channels/p2p_channel_test.exs`
  # with the wire itself: rate limiting and validation happen where the signal
  # arrives, and it no longer arrives here.
end
