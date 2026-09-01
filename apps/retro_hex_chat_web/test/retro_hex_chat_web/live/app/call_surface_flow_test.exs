defmodule RetroHexChatWeb.App.CallSurfaceFlowTest do
  @moduledoc """
  Being inside a conference, which happens at `/call/:token` and nowhere else.

  These flows used to be driven through the chat's Group Call window. There is
  no such window: a conference has one door and it is the card the chat writes
  into the channel when the room is opened. So each test here does both halves —
  the chat's control creates the room, and the test follows the address that
  card carries, the way a reader does.

  What the chat still draws *about* a call it cannot reach — the badge, the
  glyph, the status zone — is asserted in `chat_live/group_call_flow_test.exs`.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Calls.Events, as: CallEvents
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.Queries
  alias RetroHexChat.GroupCall.Registry
  alias RetroHexChat.GroupCall.RoomServer
  alias RetroHexChat.Services.RegisteredNick

  defp unique_nick(prefix), do: "#{prefix}#{uid()}" |> String.slice(0, 16)

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp mount_identified(conn, prefix) do
    nick = register(unique_nick(prefix))
    session_conn = chat_conn(conn, nick.nickname, pre_identified: true)
    {:ok, view, _html} = live(session_conn, "/chat")
    Process.put({:conn, view.pid}, session_conn)
    %{nick: nick, view: view}
  end

  defp mount_trusted_identified(conn, prefix) do
    nick = register(unique_nick(prefix))

    {:ok, %{device: device, cookie_value: cookie}} =
      TrustedDevices.remember_nick(nil, nick.nickname)

    session_conn =
      chat_conn(conn, nick.nickname, pre_identified: true, trusted_device_cookie: cookie)

    {:ok, view, _html} = live(session_conn, "/chat")

    Process.put({:conn, view.pid}, session_conn)
    %{nick: nick, device: device, view: view}
  end

  # The conference is a LiveView of its own, with no parent and no window in
  # the chat. Opening one is two acts and a test does both the way a person
  # does: the chat's control creates the room and writes the card into the
  # channel, and the call is reached at the address that card carries.
  #
  # Two independent LiveViews, so the test remembers which surface it opened
  # for which chat instead of looking for a child that does not exist.
  defp call_view(view), do: Process.get({:call_view, view.pid})

  # A surface that has left its page holds no call, which is the same answer as
  # never having opened one — and the honest one for a test asking whether this
  # person is still in a conference.
  defp call_assigns(view) do
    case call_view(view) do
      nil -> %{}
      call -> :sys.get_state(call.pid).socket.assigns
    end
  catch
    :exit, _gone -> %{}
  end

  defp group_call_assign(view), do: Map.get(call_assigns(view), :group_call)
  defp group_call_prejoin(view), do: Map.get(call_assigns(view), :group_call_prejoin)

  defp active_channel(view), do: :sys.get_state(view.pid).socket.assigns.session.active_channel

  # Both processes: a control on the call does not reach the chat, and a chat
  # control does not reach the call, so neither is settled by settling the other.
  defp flush(view) do
    state = :sys.get_state(view.pid)
    settle_call(call_view(view))
    state
  end

  # Leaving a conference leaves its page, so the surface is gone by the time the
  # next settle runs. A surface that left is the end of a leave, not a failure.
  defp settle_call(nil), do: :ok

  defp settle_call(call) do
    :sys.get_state(call.pid)
  catch
    :exit, _gone -> :ok
  end

  # The conference shortcuts are bound on the call's own page, so a test presses
  # the key there and lets the domain's binding table resolve it — the same
  # table the cheatsheet reads.
  defp press(view, key) do
    html =
      render_keydown(call_view(view), "call_keydown", %{
        "key" => key,
        "ctrlKey" => true,
        "shiftKey" => true,
        "altKey" => false
      })

    flush(view)
    html
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

  defp channel_role_rank("owner"), do: 4
  defp channel_role_rank("operator"), do: 3
  defp channel_role_rank("half_operator"), do: 2
  defp channel_role_rank("voiced"), do: 1
  defp channel_role_rank("regular"), do: 0
  defp channel_role_rank(_role), do: nil

  defp ui_can_moderate?(actor_role, target_role) do
    actor_rank = channel_role_rank(actor_role)
    target_rank = channel_role_rank(target_role)

    is_integer(actor_rank) and is_integer(target_rank) and
      actor_rank >= channel_role_rank("half_operator") and actor_rank > target_rank
  end

  defp ui_can_remove?(actor_role, target_role) do
    actor_rank = channel_role_rank(actor_role)
    target_rank = channel_role_rank(target_role)

    actor_role in ["owner", "operator"] and is_integer(actor_rank) and is_integer(target_rank) and
      actor_rank > target_rank
  end

  defp cleanup_room(token) do
    on_exit(fn ->
      case Registry.lookup_room({:room, token}) do
        {:ok, pid} -> stop_room(pid)
        {:error, :not_found} -> :ok
      end
    end)
  end

  # The room writes its participants out as it terminates, on a sandbox
  # connection borrowed from a process that is itself on its way out — so this
  # stop can exit on a dead process or on a checkout the pool has already torn
  # down. Either way the room is gone, which is all the cleanup wanted.
  defp stop_room(pid) do
    GenServer.stop(pid, :normal)
  catch
    :exit, _reason -> :ok
  end

  defp wait_until(fun, retries \\ 30)

  defp wait_until(fun, retries) do
    case fun.() do
      true ->
        :ok

      _other when retries <= 0 ->
        flunk("condition was not met before timeout")

      _other ->
        Process.sleep(20)
        wait_until(fun, retries - 1)
    end
  end

  # The chat's control creates a room only when the channel has none; once one
  # exists the control is an anchor to its address, because that address is the
  # only way into a conference. Either way, entering is following the address.
  defp open_prejoin(view) do
    channel = active_channel(view)
    room = ensure_room(view, channel)
    cleanup_room(room.token)

    # The same session the chat is on, trusted-device cookie and all: the
    # antechamber's remembered devices belong to the terminal, not the screen.
    {:ok, call, _html} = live(Process.get({:conn, view.pid}), "/call/#{room.token}")

    Process.put({:call_view, view.pid}, call)

    assert has_element?(call, ~s([data-testid="group-call-prejoin"]))
    assert has_element?(call, ~s([data-testid="group-call-prejoin-form"]))
    refute group_call_assign(view)

    group_call_prejoin(view)
  end

  defp ensure_room(view, channel) do
    case GroupCall.active_room_for_channel(channel) do
      nil ->
        view |> element(~s([data-testid="group-call-open"])) |> render_click()
        :sys.get_state(view.pid)

        GroupCall.active_room_for_channel(channel) ||
          flunk("the chat's control did not open a room in #{channel}")

      room ->
        room
    end
  end

  defp confirm_prejoin(view, overrides \\ %{}) do
    params =
      Map.merge(
        %{
          "audio" => "true",
          "video" => "true",
          "layout_mode" => "auto",
          "self_view" => "tile",
          "audio_input_id" => "",
          "video_input_id" => "",
          "audio_output_id" => ""
        },
        overrides
      )

    view
    |> call_view()
    |> element(~s([data-testid="group-call-prejoin-form"]))
    |> render_submit(%{"group_call_prejoin" => params})

    flush(view)
  end

  defp open_group_call(view, overrides \\ %{}) do
    open_prejoin(view)
    confirm_prejoin(view, overrides)
  end

  # The participant panel is bound to the People tab, so anything asserting on
  # participant rows has to open that section first.
  defp open_people_section(view) do
    call_click(view, "group_call_console_select", %{"section" => "people"})
    view
  end

  # Every conference event is the surface's; the chat forwards nothing any more.
  defp call_click(view, event, params) do
    html = render_click(call_view(view), event, params)
    flush(view)
    html
  end

  defp join_runtime_group_call(call, nick) do
    {:ok, payload} =
      GroupCall.join_call(
        call.token,
        %{user_id: nick.id, nickname: nick.nickname},
        self(),
        %{"browser" => "liveview-test"},
        %{}
      )

    assert_receive {:"$gen_cast", {:group_call_push, "group_call_offer", _payload}}, 2_000
    payload
  end

  defp mark_runtime_ready(call, payload) do
    {:ok, room_pid} = Registry.lookup_room({:room, call.token})
    :ok = RoomServer.mark_ready(room_pid, payload.participant.id)

    wait_until(fn ->
      case Queries.get_participant(payload.participant.id) do
        %{status: "connected"} -> true
        _other -> false
      end
    end)
  end

  describe "inside a conference, at its own address" do
    # Recovery is reopening the address. The chat used to reopen a conference
    # for you on reconnect; it has no conference to reopen, and the room server
    # is the authority on the seat either way — so coming back is arriving at
    # the same address and finding the seat still yours.
    test "reopening the address rejoins the seat the room still holds", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gchr")

      open_group_call(view)
      call = group_call_assign(view)
      cleanup_room(call.token)

      payload = join_runtime_group_call(call, nick)
      mark_runtime_ready(call, payload)

      assert :ok =
               GroupCall.disconnect_call(
                 call.token,
                 payload.participant.id,
                 self(),
                 "channel_closed"
               )

      {:ok, reopened, _html} =
        live(Process.get({:conn, view.pid}), "/call/#{call.token}")

      rehydrated = :sys.get_state(reopened.pid).socket.assigns.group_call

      assert rehydrated.token == call.token
      assert rehydrated.channel_name == call.channel_name
      assert rehydrated.participant_id == payload.participant.id
      assert rehydrated.status == :reconnecting
      assert rehydrated.recovery.state == :rejoining

      assert has_element?(reopened, ~s([data-testid="group-call-window"]))

      assert has_element?(
               reopened,
               ~s([data-testid="group-call-webrtc"][data-participant-id="#{payload.participant.id}"])
             )
    end

    test "pre-join media defaults are applied to the call before WebRTC mounts", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcpk")

      open_group_call(view, %{
        "audio" => "false",
        "video" => "false",
        "layout_mode" => "focus",
        "self_view" => "hidden"
      })

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert call.media == %{audio: false, video: false}
      assert call.layout.mode == :focus
      assert call.layout.self_view == :hidden

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-webrtc"][data-audio="false"][data-video="false"])
             )
    end

    test "pre-join loads trusted-device conference preferences", %{conn: conn} do
      %{nick: nick, device: device, view: view} = mount_trusted_identified(conn, "gcpp")

      assert :ok =
               TrustedDevices.put_device_preference(
                 device.id,
                 nick.nickname,
                 "group_call_prejoin",
                 %{
                   "media" => %{"audio" => false, "video" => false},
                   "layout" => %{
                     "mode" => "focus",
                     "self_view" => "hidden"
                   },
                   "device_preferences" => %{
                     "audio_input_id" => "mic-trusted",
                     "video_input_id" => "cam-trusted",
                     "audio_output_id" => "out-trusted"
                   }
                 }
               )

      prejoin = open_prejoin(view)

      refute prejoin.media.audio
      refute prejoin.media.video
      assert prejoin.layout.mode == :focus
      assert prejoin.layout.self_view == :hidden

      assert prejoin.device_preferences == %{
               audio_input_id: "mic-trusted",
               video_input_id: "cam-trusted",
               audio_output_id: "out-trusted"
             }

      refute has_element?(call_view(view), ~s([data-testid="group-call-prejoin-audio"][checked]))

      refute has_element?(
               call_view(view),
               ~s([data-testid="group-call-prejoin-video-toggle"][checked])
             )
    end

    test "pre-join saves media and device preferences on a trusted terminal", %{conn: conn} do
      %{nick: nick, device: device, view: view} = mount_trusted_identified(conn, "gcps")

      open_group_call(view, %{
        "audio" => "false",
        "video" => "true",
        "layout_mode" => "speaker",
        "self_view" => "pip",
        "audio_input_id" => "mic-save",
        "video_input_id" => "cam-save",
        "audio_output_id" => "out-save"
      })

      assert TrustedDevices.get_device_preference(
               device.id,
               nick.nickname,
               "group_call_prejoin"
             ) == %{
               "media" => %{"audio" => false, "video" => true},
               "layout" => %{"mode" => "speaker", "self_view" => "pip"},
               "device_preferences" => %{
                 "audio_input_id" => "mic-save",
                 "video_input_id" => "cam-save",
                 "audio_output_id" => "out-save"
               }
             }
    end

    test "hook events populate participants and leave tears the window down", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfd")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "joining",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        },
        "participants" => []
      })

      assert group_call_assign(view).participant_id == 123

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-123"]),
               nick.nickname
             )

      call_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => false, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      assert group_call_assign(view).status == :connected

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-123"]),
               "Connected"
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-123"][data-media-audio="false"][data-media-video="true"])
             )

      call_click(view, "group_call_toggle_audio", %{})

      assert_push_event(call_view(view), "group_call_set_media_state", %{
        audio: false,
        video: true
      })

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-123"][data-media-audio="false"][data-media-video="true"])
             )

      call_click(view, "group_call_media_state_forced", %{
        "audio" => false,
        "video" => false,
        "server_video_blocked" => true
      })

      call = group_call_assign(view)
      assert call.media.video == false
      assert call.media.server_video_blocked == true

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-123"][data-media-video="false"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-123"] [data-group-call-participant-video][data-media-moderated="true"])
             )

      assert render(call_view(view)) =~ "Camera disabled by moderator"

      call_click(view, "group_call_toggle_video", %{})
      assert group_call_assign(view).media.video == false

      call_click(view, "group_call_leave", %{})
      flush(view)

      assert has_element?(call_view(view), ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert group_call_assign(view)

      call_click(view, "group_call_confirm_leave", %{})
      flush(view)

      assert group_call_assign(view) == nil
      assert_redirect(call_view(view), "/chat")
    end

    test "conference layout controls update focus, self view, and participant rail", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfl")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        },
        "participants" => []
      })

      call_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "Ada",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      assert group_call_assign(view).layout.mode == :auto

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-layout-auto"][aria-pressed="true"])
             )

      assert has_element?(call_view(view), ~s([data-testid="group-call-participant-focus-456"]))

      call_click(view, "group_call_layout_mode", %{"mode" => "grid"})
      assert group_call_assign(view).layout.mode == :grid
      assert_push_event(call_view(view), "group_call_layout_state", %{mode: "grid"})

      call_click(view, "group_call_focus_participant", %{"participant-id" => "456"})
      call = group_call_assign(view)
      assert call.layout.mode == :focus
      assert call.layout.focused_participant_id == 456

      assert_push_event(call_view(view), "group_call_layout_state", %{
        mode: "focus",
        focused_participant_id: 456
      })

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-focus-456"][aria-pressed="true"])
             )

      call_click(view, "group_call_cycle_self_view", %{})
      assert group_call_assign(view).layout.self_view == :pip
      assert_push_event(call_view(view), "group_call_layout_state", %{self_view: "pip"})

      # The participant panel follows the People tab, not a separate toggle.
      call_click(view, "group_call_console_select", %{"section" => "call"})
      assert group_call_assign(view).layout.console_section == :call
      refute has_element?(call_view(view), ~s([data-testid="group-call-participants"]))

      call_click(view, "group_call_console_select", %{"section" => "people"})
      assert group_call_assign(view).layout.console_section == :people
      assert has_element?(call_view(view), ~s([data-testid="group-call-participants"]))
    end

    test "advanced layouts follow speaker state and pin participants", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcsp")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        },
        "participants" => []
      })

      call_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "Ada",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      call_click(view, "group_call_participant_quality", %{
        "active_speaker_participant_id" => "456",
        "participants" => [
          %{
            "participant_id" => "456",
            "level" => "good",
            "speaking" => true,
            "rtt_ms" => 80
          }
        ]
      })

      call_click(view, "group_call_layout_mode", %{"mode" => "speaker"})

      call = group_call_assign(view)
      assert call.layout.mode == :speaker
      assert call.layout.focused_participant_id == 456

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-layout-speaker"][aria-pressed="true"])
             )

      assert_push_event(call_view(view), "group_call_layout_state", %{
        mode: "speaker",
        focused_participant_id: 456
      })

      call_click(view, "group_call_toggle_pin_participant", %{"participant-id" => "456"})

      assert group_call_assign(view).layout.pinned_participant_ids == [456]

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-pin-456"][aria-pressed="true"])
             )

      assert_push_event(call_view(view), "group_call_layout_state", %{
        pinned_participant_ids: [456]
      })

      call_click(view, "group_call_toggle_pin_participant", %{"participant-id" => "456"})

      assert group_call_assign(view).layout.pinned_participant_ids == []

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-pin-456"][aria-pressed="false"])
             )
    end

    test "keyboard shortcuts control active conference media, layout, focus, and leave", %{
      conn: conn
    } do
      %{nick: nick, view: view} = mount_identified(conn, "gcks")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        },
        "participants" => []
      })

      call_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "Ada",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      press(view, "ArrowUp")

      assert_push_event(call_view(view), "group_call_set_media_state", %{
        audio: false,
        video: true
      })

      refute group_call_assign(view).media.audio

      press(view, "ArrowLeft")

      assert_push_event(call_view(view), "group_call_set_media_state", %{
        audio: false,
        video: false
      })

      refute group_call_assign(view).media.video

      press(view, "ArrowRight")
      assert group_call_assign(view).layout.mode == :grid
      assert_push_event(call_view(view), "group_call_layout_state", %{mode: "grid"})

      press(view, "ArrowDown")
      call = group_call_assign(view)
      assert call.layout.mode == :focus
      assert call.layout.focused_participant_id == 456

      assert_push_event(call_view(view), "group_call_layout_state", %{
        mode: "focus",
        focused_participant_id: 456
      })

      press(view, "q")
      assert has_element?(call_view(view), ~s|#group-call-confirm-dialog:not(.hidden)|)
    end

    test "conference exposes keyboard and screen-reader semantics", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcax")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-panel"][role="region"][aria-label="Channel conference"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-webrtc"][role="region"][aria-label="Conference media"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-layout-controls"][role="toolbar"][aria-label="Conference layout controls"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-reactions"][role="toolbar"][aria-label="Conference reactions"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-remote-placeholder"][role="status"][aria-live="polite"])
             )

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        },
        "participants" => []
      })

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participants"][role="list"][aria-label="Conference participant list"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-123"][role="listitem"])
             )

      call_click(view, "group_call_client_warning", %{
        "message" => "Network quality degraded."
      })

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-warning"][role="status"][aria-live="polite"]),
               "Network quality degraded."
             )

      attach_call_telemetry()

      call_click(view, "group_call_client_error", %{
        "code" => "media_negotiation_failed",
        "message" => "Media connection failed."
      })

      assert_receive {:call_telemetry, event, %{count: 1},
                      %{
                        surface: "group_call",
                        code: "media_negotiation_failed",
                        phase: "liveview_client_error"
                      }}

      assert event == CallEvents.client_error_event()

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-error"][role="alert"][aria-live="assertive"]),
               "Media connection failed."
             )
    end

    test "conference renders rich empty and failure states with clear actions", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcef")

      open_group_call(view, %{"audio" => "false", "video" => "false"})
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-remote-placeholder"]),
               "Waiting for participants"
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-local-empty"]),
               "Receive-only mode"
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participants-loading"][role="listitem"]),
               "Joining conference"
             )

      call_click(view, "group_call_client_warning", %{
        "message" => "Could not access your microphone or camera. You joined receive-only."
      })

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-warning-title"]),
               "Media warning"
             )

      assert has_element?(call_view(view), ~s([data-testid="group-call-warning"]), "receive-only")

      attach_call_telemetry()

      call_click(view, "group_call_recovery_state", %{
        "state" => "failed",
        "reason" => "offer_not_received",
        "trigger" => "offer_watchdog",
        "manual_retry" => true,
        "attempt" => 3,
        "max_attempts" => 3,
        "message" => "Media recovery failed. Retry the media connection."
      })

      assert_receive {:call_telemetry, event, %{count: 1},
                      %{
                        surface: "group_call",
                        state: "failed",
                        reason: "offer_not_received",
                        trigger: "offer_watchdog",
                        attempt: 3,
                        max_attempts: 3,
                        manual_retry: true
                      }}

      assert event == CallEvents.recovery_transition_event()

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-error-title"]),
               "Connection needs attention"
             )

      assert has_element?(call_view(view), ~s([data-testid="group-call-retry"]))
      assert has_element?(call_view(view), ~s([data-testid="group-call-leave-from-error"]))

      call_view(view)
      |> element(~s([data-testid="group-call-leave-from-error"]))
      |> render_click()

      assert has_element?(call_view(view), ~s|#group-call-confirm-dialog:not(.hidden)|)
    end

    test "mini mode keeps the WebRTC surface mounted with compact controls", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcmi")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-webrtc"][data-group-call-token="#{call.token}"])
             )

      call_view(view)
      |> element(~s([data-testid="group-call-mini-toggle"]))
      |> render_click()

      assert_push_event(call_view(view), "group_call_layout_state", %{mini: true})
      assert group_call_assign(view).layout.mini == true

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-panel"][data-mini-mode="true"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-webrtc"][data-group-call-token="#{call.token}"])
             )

      refute has_element?(call_view(view), ~s([data-testid="group-call-participants"]))
      assert has_element?(call_view(view), ~s([data-testid="group-call-mini-audio-toggle"]))
      assert has_element?(call_view(view), ~s([data-testid="group-call-mini-video-toggle"]))
      assert has_element?(call_view(view), ~s([data-testid="group-call-mini-leave"]))
      assert has_element?(call_view(view), ~s([data-testid="group-call-mini-expand"]))

      call_view(view)
      |> element(~s([data-testid="group-call-mini-audio-toggle"]))
      |> render_click()

      assert_push_event(call_view(view), "group_call_set_media_state", %{
        audio: false,
        video: true
      })

      call_view(view)
      |> element(~s([data-testid="group-call-mini-expand"]))
      |> render_click()

      assert_push_event(call_view(view), "group_call_layout_state", %{mini: false})
      assert group_call_assign(view).layout.mini == false

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-panel"][data-mini-mode="false"])
             )
    end

    test "stats section renders inside the conference console", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcst")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_view(view)
      |> element(~s([data-testid="group-call-section-stats"]))
      |> render_click()

      assert group_call_assign(view).layout.console_section == :stats
      assert has_element?(call_view(view), ~s([data-testid="group-call-inline-stats"]))

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-inline-stats"] [data-testid="group-call-stats-panel"])
             )
    end

    test "browser stats update the inline conference statistics section", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcfs")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_stats", %{
        "connection" => %{
          "level" => "good",
          "mos" => 4.1,
          "rtt_ms" => 42,
          "jitter_ms" => 7,
          "loss_pct" => 1.5,
          "available_kbps" => 3200
        },
        "audio" => %{
          "active" => true,
          "in_kbps" => 64,
          "out_kbps" => 48,
          "loss_pct" => 0,
          "jitter_ms" => 3
        },
        "video" => %{
          "active" => true,
          "in_kbps" => 900,
          "out_kbps" => 700,
          "loss_pct" => 2,
          "jitter_ms" => 8,
          "fps" => 30,
          "width" => 1280,
          "height" => 720,
          "freeze_count" => 1,
          "limitation" => "bandwidth"
        },
        "summary" => %{
          "connection_state" => "connected",
          "participant_count" => 2,
          "remote_stream_count" => 1,
          "track_count" => 4
        }
      })

      call = group_call_assign(view)
      assert call.stats.connection.rtt_ms == 42
      assert call.stats.audio.active
      assert call.stats.video.width == 1280
      assert call.stats.summary.remote_stream_count == 1
      assert call.status == :connected
      assert call.connection_state == "connected"

      call_view(view)
      |> element(~s([data-testid="group-call-section-stats"]))
      |> render_click()

      assert group_call_assign(view).layout.console_section == :stats
      assert has_element?(call_view(view), ~s([data-testid="group-call-inline-stats"]))
      assert has_element?(call_view(view), ~s([data-testid="group-call-stats-summary"]))

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-stats-summary-health"]),
               "Good"
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-stats-summary-latency"]),
               "42 ms"
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-stats-details-browser-connection"])
             )

      assert has_element?(call_view(view), ~s([data-testid="group-call-stats-details-audio"]))
      assert has_element?(call_view(view), ~s([data-testid="group-call-stats-details-video"]))

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-stats-details-browser-summary"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-stats-summary-media"]),
               "Audio + Video"
             )

      assert has_element?(call_view(view), ~s([data-testid="group-call-stats-health"]), "Good")
      assert render(call_view(view)) =~ "1280x720"
    end

    test "renegotiation does not downgrade a connected conference status", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcrs")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_connection_state", %{"state" => "connected"})

      assert group_call_assign(view).status == :connected

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-status-announcer"]),
               "Connected"
             )

      call_click(view, "group_call_offer_received", %{})

      assert group_call_assign(view).status == :connected

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-status-announcer"]),
               "Connected"
             )
    end

    test "screen share state updates controls, participant state, focus, and stats", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcsh")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "active",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        },
        "participants" => []
      })

      call_click(view, "group_call_screen_share_state", %{
        "active" => true,
        "participant_id" => 123,
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true, "screen" => true},
          "channel_role_snapshot" => "regular"
        },
        "track" => %{
          "id" => 7,
          "participant_id" => 123,
          "kind" => "video",
          "source" => "screen",
          "status" => "active",
          "webrtc_track_id" => "screen-track",
          "stream_id" => "screen-stream"
        }
      })

      call = group_call_assign(view)
      assert call.media.screen
      assert call.layout.mode == :focus
      assert call.layout.focused_participant_id == 123
      assert Enum.any?(call.tracks, &(&1.source == "screen"))

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-screen-share-toggle"][aria-pressed="true"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-123"][data-media-screen="true"])
             )

      call_view(view)
      |> element(~s([data-testid="group-call-section-stats"]))
      |> render_click()

      assert has_element?(call_view(view), ~s([data-testid="group-call-inline-stats"]))
      assert render(call_view(view)) =~ "Screen tracks"

      call_click(view, "group_call_screen_share_state", %{
        "active" => false,
        "participant_id" => 123,
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true, "screen" => false},
          "channel_role_snapshot" => "regular"
        },
        "track" => %{
          "id" => 7,
          "participant_id" => 123,
          "kind" => "video",
          "source" => "camera",
          "status" => "active"
        }
      })

      refute group_call_assign(view).media.screen

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-screen-share-toggle"][aria-pressed="false"])
             )
    end

    test "participant quality state renders active speaker and quality badges", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcql")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "active",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        },
        "participants" => [
          %{
            "id" => 456,
            "nickname" => "Ada",
            "status" => "connected",
            "media_state" => %{"audio" => true, "video" => true},
            "channel_role_snapshot" => "regular"
          }
        ]
      })

      refute has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-quality-456"])
             )

      call_click(view, "group_call_participant_quality", %{
        "active_speaker_participant_id" => 456,
        "participants" => [
          %{
            "participant_id" => 456,
            "level" => "poor",
            "speaking" => true,
            "rtt_ms" => 260,
            "jitter_ms" => 55,
            "loss_pct" => 8.5,
            "bitrate_kbps" => 240,
            "fps" => 12,
            "freeze_count" => 3
          }
        ]
      })

      call = group_call_assign(view)
      assert call.participant_quality.active_speaker_participant_id == 456
      assert call.participant_quality.by_participant[456].level == :poor

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-456"][data-active-speaker="true"][data-quality-level="poor"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-quality-456"][data-quality-level="poor"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-active-speaker-456"])
             )

      assert render(call_view(view)) =~ "RTT 260 ms"
    end

    test "conference reactions render on participant rows without chat spam", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcrx")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "active",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        },
        "participants" => [
          %{
            "id" => 456,
            "nickname" => "Ada",
            "status" => "connected",
            "media_state" => %{"audio" => true, "video" => true},
            "channel_role_snapshot" => "regular"
          }
        ]
      })

      for reaction <- ["heart", "thumbs_up", "clap", "laugh", "wow"] do
        assert has_element?(
                 call_view(view),
                 ~s([data-testid="group-call-reaction-icon-#{reaction}"] svg)
               )
      end

      html = render(call_view(view))
      refute html =~ "👍"
      refute html =~ "👏"
      refute html =~ "😄"
      refute html =~ "✨"

      call_click(view, "group_call_reaction", %{
        "id" => "reaction-1",
        "participant_id" => "456",
        "nickname" => "Ada",
        "reaction" => "clap",
        "emoji" => "👏",
        "occurred_at_ms" => 123
      })

      call = group_call_assign(view)
      assert [%{participant_id: 456, reaction: "clap", emoji: "👏"}] = call.reactions

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-reaction-456"][data-reaction="clap"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-reaction-icon-456"] svg)
             )

      html = render(call_view(view))
      refute html =~ "👏"
    end

    test "server stats from the SFU summary render beside browser stats", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfr")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "active",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        },
        "participants" => [
          %{
            "id" => 123,
            "nickname" => nick.nickname,
            "status" => "connected",
            "media_state" => %{"audio" => true, "video" => true},
            "channel_role_snapshot" => "regular"
          }
        ],
        "tracks" => [
          %{
            "id" => 1,
            "participant_id" => 123,
            "kind" => "audio",
            "source" => "microphone",
            "status" => "active"
          },
          %{
            "id" => 2,
            "participant_id" => 123,
            "kind" => "video",
            "source" => "camera",
            "status" => "active"
          }
        ],
        "server_stats" => %{
          "room" => %{
            "status" => "active",
            "max_participants" => 100,
            "participant_count" => 1,
            "pending_count" => 0,
            "track_count" => 2,
            "audio_track_count" => 1,
            "video_track_count" => 1
          },
          "totals" => %{
            "peer_count" => 1,
            "connected_peer_count" => 1,
            "inbound_track_count" => 2,
            "outbound_peer_count" => 3,
            "subscriber_count" => 2,
            "inbound_packets" => 12,
            "inbound_bytes" => 2048,
            "outbound_packets" => 24,
            "outbound_bytes" => 4096,
            "nack_count" => 1,
            "pli_count" => 2,
            "candidate_pair_count" => 2,
            "nominated_pair_count" => 1,
            "ice_bytes_sent" => 1024,
            "ice_bytes_received" => 2048
          },
          "peers" => [
            %{
              "participant_id" => 123,
              "nickname" => nick.nickname,
              "connection_state" => "connected",
              "ice_connection_state" => "completed",
              "signaling_state" => "stable",
              "inbound_track_count" => 2,
              "outbound_peer_count" => 3,
              "subscriber_count" => 2,
              "inbound_rtp" => %{
                "track_count" => 2,
                "packets" => 15,
                "bytes" => 3072,
                "nack_count" => 1,
                "pli_count" => 0
              },
              "outbound_rtp" => %{
                "track_count" => 6,
                "packets" => 30,
                "bytes" => 6144,
                "nack_count" => 2,
                "pli_count" => 3
              },
              "candidate_pairs" => %{
                "total" => 4,
                "nominated" => 1,
                "valid" => 2,
                "packets_sent" => 10,
                "packets_received" => 20,
                "bytes_sent" => 4096,
                "bytes_received" => 8192
              }
            }
          ]
        }
      })

      call = group_call_assign(view)
      assert call.server_stats.totals.inbound_bytes == 2048
      assert call.server_stats.totals.outbound_peer_count == 3
      assert [%{candidate_pairs: %{valid: 2}, nickname: peer_nickname}] = call.server_stats.peers
      assert peer_nickname == nick.nickname

      call_view(view)
      |> element(~s([data-testid="group-call-section-stats"]))
      |> render_click()

      html = render(call_view(view))
      assert html =~ "Server runtime"
      assert html =~ ~s(data-testid="group-call-stats-details-server-runtime")
      assert html =~ ~s(data-testid="group-call-stats-details-server-peers")
      assert html =~ "Server peers"
      assert html =~ "1/1 connected"
      assert html =~ "12 pkt / 2 KB"
      assert html =~ "24 pkt / 4 KB"
      assert html =~ "NACK 1 / PLI 2"
      assert html =~ "connected / ICE completed"
      assert html =~ "2 in / 3 fanout"
      assert html =~ "2 trk / 15 pkt / 3 KB"
      assert html =~ "6 trk / 30 pkt / 6 KB"
      assert html =~ "1/4 nominated / 2 valid"
      assert html =~ "4 KB up / 8 KB down"
      assert html =~ "NACK 3 / PLI 3"
    end

    test "media warnings stay recoverable while failed connection becomes actionable error", %{
      conn: conn
    } do
      %{view: view} = mount_identified(conn, "gcfw")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_warning", %{
        "code" => "media_capture_failed",
        "message" => "Could not access your microphone or camera. You joined receive-only."
      })

      call = group_call_assign(view)
      assert call.status == :joining

      assert call.warning ==
               "Could not access your microphone or camera. You joined receive-only."

      refute call.error

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-warning"]),
               "receive-only"
             )

      call_click(view, "group_call_connection_state", %{"state" => "disconnected"})

      call = group_call_assign(view)
      assert call.connection_state == "disconnected"
      assert call.status == :reconnecting
      assert call.warning =~ "Trying to recover"
      refute call.error

      call_click(view, "group_call_connection_state", %{"state" => "failed"})

      call = group_call_assign(view)
      assert call.status == :error
      assert call.connection_state == "failed"
      assert call.error =~ "Retry the media connection"
      refute call.warning

      assert has_element?(call_view(view), ~s([data-testid="group-call-error"]), "Retry")
      refute has_element?(call_view(view), ~s([data-testid="group-call-warning"]))

      call_click(view, "group_call_recovery_state", %{
        "state" => "failed",
        "manual_retry" => true,
        "attempt" => 3,
        "max_attempts" => 3,
        "message" => "Media recovery failed. Retry the media connection."
      })

      call = group_call_assign(view)
      assert call.recovery.state == :failed
      assert call.recovery.manual_retry

      assert has_element?(call_view(view), ~s([data-testid="group-call-retry"]))

      call_view(view)
      |> element(~s([data-testid="group-call-retry"]))
      |> render_click()

      assert_push_event(call_view(view), "group_call_retry_media", %{trigger: "manual"})
    end

    test "moderators see call and participant moderation controls", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfm")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "owner"
        },
        "participants" => []
      })

      call_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "TargetUser",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      assert has_element?(call_view(view), ~s([data-testid="group-call-close-room"]))

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-audio-moderate-456"])
             )

      assert has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-video-moderate-456"])
             )

      assert has_element?(call_view(view), ~s([data-testid="group-call-participant-kick-456"]))
      refute has_element?(call_view(view), ~s([data-testid="group-call-participant-kick-123"]))

      call_click(view, "group_call_close_room", %{})
      flush(view)

      assert has_element?(call_view(view), ~s|#group-call-confirm-dialog:not(.hidden)|)

      call_click(view, "group_call_confirm_cancel", %{})
      flush(view)

      assert group_call_assign(view)
    end

    test "participant moderation buttons follow the channel permission matrix", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcpm")

      open_group_call(view)
      open_people_section(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      roles = ["owner", "operator", "half_operator", "voiced", "regular"]

      for actor_role <- roles, target_role <- roles do
        call_click(view, "group_call_client_joined", %{
          "room" => %{
            "id" => call.room.id,
            "token" => call.token,
            "channel_name" => call.channel_name,
            "status" => "open",
            "max_participants" => call.room.max_participants
          },
          "participant" => %{
            "id" => 123,
            "nickname" => nick.nickname,
            "status" => "connected",
            "media_state" => %{"audio" => true, "video" => true},
            "channel_role_snapshot" => actor_role
          },
          "participants" => []
        })

        call_click(view, "group_call_peer_joined", %{
          "participant" => %{
            "id" => 456,
            "nickname" => "TargetUser",
            "status" => "connected",
            "media_state" => %{"audio" => true, "video" => true},
            "channel_role_snapshot" => target_role
          }
        })

        if actor_role in ["owner", "operator", "half_operator"] do
          assert has_element?(call_view(view), ~s([data-testid="group-call-close-room"]))
        else
          refute has_element?(call_view(view), ~s([data-testid="group-call-close-room"]))
        end

        if ui_can_moderate?(actor_role, target_role) do
          assert has_element?(
                   call_view(view),
                   ~s([data-testid="group-call-participant-audio-moderate-456"])
                 )

          assert has_element?(
                   call_view(view),
                   ~s([data-testid="group-call-participant-video-moderate-456"])
                 )
        else
          refute has_element?(
                   call_view(view),
                   ~s([data-testid="group-call-participant-audio-moderate-456"])
                 )

          refute has_element?(
                   call_view(view),
                   ~s([data-testid="group-call-participant-video-moderate-456"])
                 )
        end

        if ui_can_remove?(actor_role, target_role) do
          assert has_element?(
                   call_view(view),
                   ~s([data-testid="group-call-participant-kick-456"])
                 )
        else
          refute has_element?(
                   call_view(view),
                   ~s([data-testid="group-call-participant-kick-456"])
                 )
        end
      end

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "owner"
        },
        "participants" => []
      })

      call_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "RoleMissing",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => nil
        }
      })

      refute has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-audio-moderate-456"])
             )

      refute has_element?(
               call_view(view),
               ~s([data-testid="group-call-participant-video-moderate-456"])
             )

      refute has_element?(call_view(view), ~s([data-testid="group-call-participant-kick-456"]))
    end

    test "bulk moderation confirms and updates lower-ranked participants", %{conn: conn} do
      moderator = mount_identified(conn, "gcbm")
      target = register(unique_nick("gcbt"))
      channel = "#gcbulk#{uid()}"

      submit_command_sync(moderator.view, "/join #{channel}")
      {:ok, _state} = Server.join(channel, target.nickname, nil, identified: true)

      open_group_call(moderator.view)

      call = group_call_assign(moderator.view)
      cleanup_room(call.token)

      moderator_payload = join_runtime_group_call(call, moderator.nick)
      target_payload = join_runtime_group_call(call, target)
      mark_runtime_ready(call, moderator_payload)
      mark_runtime_ready(call, target_payload)
      flush(moderator.view)

      call_click(moderator.view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => channel,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => moderator_payload.participant.id,
          "nickname" => moderator.nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "owner"
        },
        "participants" => []
      })

      call_click(moderator.view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => target_payload.participant.id,
          "nickname" => target.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      call_view(moderator.view)
      |> element(~s([data-testid="group-call-mute-all"]))
      |> render_click()

      flush(moderator.view)
      assert has_element?(call_view(moderator.view), ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert render(call_view(moderator.view)) =~ "Mute all lower-ranked participants"

      call_click(moderator.view, "group_call_confirm_mute_all", %{})
      flush(moderator.view)

      muted_call = group_call_assign(moderator.view)
      muted_target = Enum.find(muted_call.participants, &(&1.id == target_payload.participant.id))

      assert muted_target.media_state.audio == false
      assert muted_target.media_state.server_audio_muted == true
      assert render(moderator.view) =~ "muted 1 conference microphone"

      call_view(moderator.view)
      |> element(~s([data-testid="group-call-camera-off-all"]))
      |> render_click()

      flush(moderator.view)
      assert has_element?(call_view(moderator.view), ~s|#group-call-confirm-dialog:not(.hidden)|)

      assert render(call_view(moderator.view)) =~
               "Turn off cameras for all lower-ranked participants"

      call_click(moderator.view, "group_call_confirm_camera_off_all", %{})
      flush(moderator.view)

      camera_call = group_call_assign(moderator.view)

      camera_target =
        Enum.find(camera_call.participants, &(&1.id == target_payload.participant.id))

      assert camera_target.media_state.video == false
      assert camera_target.media_state.server_video_blocked == true
      assert render(moderator.view) =~ "turned off 1 conference camera"
    end

    test "moderators can lock and unlock the conference", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gclk")
      channel = "#gclk#{uid()}"

      submit_command_sync(view, "/join #{channel}")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      call_click(view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => call.channel_name,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => 123,
          "nickname" => call.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "owner"
        },
        "participants" => []
      })

      call_click(view, "group_call_toggle_lock", %{})

      flush(view)

      assert group_call_assign(view).room.metadata["locked"] == true
      assert render(view) =~ "locked the conference"

      call_click(view, "group_call_toggle_lock", %{})

      flush(view)

      assert group_call_assign(view).room.metadata["locked"] == false
      assert render(view) =~ "unlocked the conference"
    end

    test "conference administrative events render system messages without update spam", %{
      conn: conn
    } do
      %{view: view} = mount_identified(conn, "gcau")
      channel = "#gcaudit#{uid()}"

      submit_command_sync(view, "/join #{channel}")

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel}", {
        :group_call_moderation,
        %{
          channel: channel,
          action: :participant_muted,
          actor: "Mod",
          target: "Guest",
          event: %{"type" => "participant_muted"}
        }
      })

      flush(view)
      html = render(view)
      assert html =~ "Mod"
      assert html =~ "Guest"
      assert html =~ "conference microphone"

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel}", {
        :group_call_moderation,
        %{
          channel: channel,
          action: :screen_share_started,
          target: "Guest",
          event: %{"type" => "screen_share_started"}
        }
      })

      flush(view)
      assert render(view) =~ "started sharing a screen"

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel}", {
        :group_call_moderation,
        %{
          channel: channel,
          action: :participant_kicked,
          actor: "Mod",
          target: "Guest",
          event: %{"type" => "participant_kicked"}
        }
      })

      flush(view)
      assert render(view) =~ "removed Guest from the conference"

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel}", {
        :group_call_updated,
        %{channel: channel, reason: "media_state", summary: %{}}
      })

      flush(view)
      refute render(view) =~ "Conference moderation updated"
    end

    test "raised hand queue lets moderators allow speech", %{conn: conn} do
      moderator = mount_identified(conn, "gcrh")
      target = register(unique_nick("gcrt"))
      channel = "#gcrh#{uid()}"

      submit_command_sync(moderator.view, "/join #{channel}")
      {:ok, _state} = Server.join(channel, target.nickname, nil, identified: true)

      open_group_call(moderator.view)
      open_people_section(moderator.view)

      call = group_call_assign(moderator.view)
      cleanup_room(call.token)

      moderator_payload = join_runtime_group_call(call, moderator.nick)
      target_payload = join_runtime_group_call(call, target)

      call_click(moderator.view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => channel,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => moderator_payload.participant.id,
          "nickname" => moderator.nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "owner"
        },
        "participants" => []
      })

      call_click(moderator.view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => target_payload.participant.id,
          "nickname" => target.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      call_view(moderator.view)
      |> element(~s([data-testid="group-call-hand-toggle"]))
      |> render_click()

      self_call = group_call_assign(moderator.view)
      assert self_call.media.hand_raised == true

      call_click(moderator.view, "group_call_toggle_hand", %{})
      refute group_call_assign(moderator.view).media.hand_raised

      actor = %{user_id: moderator.nick.id, nickname: moderator.nick.nickname}
      target_actor = %{user_id: target.id, nickname: target.nickname}

      assert {:ok, muted} =
               GroupCall.mute_participant(call.token, actor, target_payload.participant.id)

      assert {:ok, raised} =
               GroupCall.set_hand_raised(
                 call.token,
                 target_actor,
                 target_payload.participant.id,
                 true
               )

      call_click(moderator.view, "group_call_media_state", %{
        "participant" => %{
          "id" => raised.id,
          "nickname" => raised.nickname,
          "status" => raised.status,
          "media_state" => raised.media_state,
          "channel_role_snapshot" => raised.channel_role_snapshot
        }
      })

      assert muted.media_state["server_audio_muted"] == true

      assert has_element?(
               call_view(moderator.view),
               ~s([data-testid="group-call-raised-hand-queue"])
             )

      assert has_element?(
               call_view(moderator.view),
               ~s([data-testid="group-call-queue-allow-speak-#{target_payload.participant.id}"])
             )

      call_view(moderator.view)
      |> element(
        ~s([data-testid="group-call-queue-allow-speak-#{target_payload.participant.id}"])
      )
      |> render_click()

      allowed = Queries.get_participant(target_payload.participant.id)
      assert allowed.media_state["audio"] == true
      assert allowed.media_state["server_audio_muted"] == false
      assert allowed.media_state["hand_raised"] == false

      refute has_element?(
               call_view(moderator.view),
               ~s([data-testid="group-call-queue-allow-speak-#{target_payload.participant.id}"])
             )
    end

    test "moderators can stop and re-allow participant screen sharing", %{conn: conn} do
      moderator = mount_identified(conn, "gcsm")
      target = register(unique_nick("gcst"))
      channel = "#gcscreen#{uid()}"

      submit_command_sync(moderator.view, "/join #{channel}")
      {:ok, _state} = Server.join(channel, target.nickname, nil, identified: true)

      open_group_call(moderator.view)
      open_people_section(moderator.view)

      call = group_call_assign(moderator.view)
      cleanup_room(call.token)

      moderator_payload = join_runtime_group_call(call, moderator.nick)
      target_payload = join_runtime_group_call(call, target)
      mark_runtime_ready(call, moderator_payload)
      mark_runtime_ready(call, target_payload)
      flush(moderator.view)

      call_click(moderator.view, "group_call_client_joined", %{
        "room" => %{
          "id" => call.room.id,
          "token" => call.token,
          "channel_name" => channel,
          "status" => "open",
          "max_participants" => call.room.max_participants
        },
        "participant" => %{
          "id" => moderator_payload.participant.id,
          "nickname" => moderator.nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "owner"
        },
        "participants" => []
      })

      assert {:ok, %{participant: sharing}} =
               GroupCall.set_screen_share_state(
                 call.token,
                 target_payload.participant.id,
                 true,
                 %{
                   "track_id" => "screen-track"
                 }
               )

      call_click(moderator.view, "group_call_screen_share_state", %{
        "active" => true,
        "participant_id" => target_payload.participant.id,
        "participant" => %{
          "id" => sharing.id,
          "nickname" => sharing.nickname,
          "status" => sharing.status,
          "media_state" => sharing.media_state,
          "channel_role_snapshot" => sharing.channel_role_snapshot
        },
        "track" => nil
      })

      assert has_element?(
               call_view(moderator.view),
               ~s([data-testid="group-call-participant-screen-moderate-#{target_payload.participant.id}"])
             )

      call_view(moderator.view)
      |> element(
        ~s([data-testid="group-call-participant-screen-moderate-#{target_payload.participant.id}"])
      )
      |> render_click()

      blocked = Queries.get_participant(target_payload.participant.id)
      assert blocked.media_state["screen"] == false
      assert blocked.media_state["server_screen_blocked"] == true

      blocked_call = group_call_assign(moderator.view)

      blocked_target =
        Enum.find(blocked_call.participants, &(&1.id == target_payload.participant.id))

      assert blocked_target.media_state.server_screen_blocked == true

      call_view(moderator.view)
      |> element(
        ~s([data-testid="group-call-participant-screen-moderate-#{target_payload.participant.id}"])
      )
      |> render_click()

      allowed = Queries.get_participant(target_payload.participant.id)
      assert allowed.media_state["server_screen_blocked"] == false
    end

    test "confirmed participant removal bans from channel and closes target conference", %{
      conn: conn
    } do
      moderator = mount_identified(conn, "gckm")
      target = mount_identified(conn, "gckt")
      channel = "#gck#{uid()}"

      submit_command_sync(moderator.view, "/join #{channel}")
      submit_command_sync(target.view, "/join #{channel}")

      open_group_call(moderator.view)
      open_people_section(moderator.view)

      mod_call = group_call_assign(moderator.view)
      cleanup_room(mod_call.token)

      open_group_call(target.view)

      assert group_call_assign(target.view).token == mod_call.token

      for {ctx, id, role} <- [{moderator, 123, "owner"}, {target, 456, "regular"}] do
        call_click(ctx.view, "group_call_client_joined", %{
          "room" => %{
            "id" => mod_call.room.id,
            "token" => mod_call.token,
            "channel_name" => channel,
            "status" => "open",
            "max_participants" => mod_call.room.max_participants
          },
          "participant" => %{
            "id" => id,
            "nickname" => ctx.nick.nickname,
            "status" => "connected",
            "media_state" => %{"audio" => true, "video" => true},
            "channel_role_snapshot" => role
          },
          "participants" => []
        })
      end

      call_click(moderator.view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => target.nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      call_view(moderator.view)
      |> element(~s([data-testid="group-call-participant-kick-456"]))
      |> render_click()

      flush(moderator.view)
      assert has_element?(call_view(moderator.view), ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert render(call_view(moderator.view)) =~ "prevent them from rejoining"

      call_click(moderator.view, "group_call_confirm_kick_participant", %{})
      flush(moderator.view)
      flush(target.view)

      assert render(call_view(moderator.view)) =~ "banned from #{channel}"

      refute has_element?(
               call_view(moderator.view),
               ~s([data-testid="group-call-participant-456"])
             )

      assert group_call_assign(target.view) == nil
      assert_redirect(call_view(target.view), "/chat")
      refute channel in :sys.get_state(target.view.pid).socket.assigns.session.channels

      assert {:error, _message} =
               Server.join(channel, target.nick.nickname, nil, identified: true)
    end

    test "half operators cannot open the remove-and-ban conference action", %{conn: conn} do
      owner = mount_identified(conn, "gcho")
      half = mount_identified(conn, "gchh")
      target = mount_identified(conn, "gcht")
      channel = "#gch#{uid()}"

      for ctx <- [owner, half, target] do
        submit_command_sync(ctx.view, "/join #{channel}")
      end

      :ok = Server.set_mode(channel, owner.nick.nickname, "+h", [half.nick.nickname])

      open_group_call(half.view)

      half_call = group_call_assign(half.view)
      cleanup_room(half_call.token)

      open_group_call(target.view)

      assert group_call_assign(target.view).token == half_call.token

      for {ctx, id, role} <- [{half, 123, "half_operator"}, {target, 456, "regular"}] do
        call_click(ctx.view, "group_call_client_joined", %{
          "room" => %{
            "id" => half_call.room.id,
            "token" => half_call.token,
            "channel_name" => channel,
            "status" => "open",
            "max_participants" => half_call.room.max_participants
          },
          "participant" => %{
            "id" => id,
            "nickname" => ctx.nick.nickname,
            "status" => "connected",
            "media_state" => %{"audio" => true, "video" => true},
            "channel_role_snapshot" => role
          },
          "participants" => []
        })
      end

      call_click(half.view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => target.nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      refute has_element?(
               call_view(half.view),
               ~s([data-testid="group-call-participant-kick-456"])
             )

      call_click(half.view, "group_call_kick_participant", %{"participant-id" => "456"})
      flush(half.view)

      refute has_element?(call_view(half.view), ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert render(call_view(half.view)) =~ "Insufficient privileges"
      assert group_call_assign(target.view)
      assert channel in :sys.get_state(target.view.pid).socket.assigns.session.channels
    end
  end
end
