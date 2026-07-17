defmodule RetroHexChatWeb.ChatLive.GroupCallFlowTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Schemas.UserPreference
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
    {:ok, view, _html} = live(chat_conn(conn, nick.nickname, pre_identified: true), "/chat")
    %{nick: nick, view: view}
  end

  defp group_call_assign(view), do: :sys.get_state(view.pid).socket.assigns.group_call
  defp group_call_prejoin(view), do: :sys.get_state(view.pid).socket.assigns.group_call_prejoin
  defp group_call_channels(view), do: :sys.get_state(view.pid).socket.assigns.group_call_channels

  defp group_call_channel_summaries(view),
    do: :sys.get_state(view.pid).socket.assigns.group_call_channel_summaries

  defp active_channel(view), do: :sys.get_state(view.pid).socket.assigns.session.active_channel
  defp flush(view), do: :sys.get_state(view.pid)

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
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end
    end)
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

  defp open_prejoin(view) do
    view
    |> element(~s([data-testid="group-call-open"]))
    |> render_click()

    flush(view)

    assert has_element?(view, ~s|#group-call-prejoin-dialog:not(.hidden)|)
    assert has_element?(view, ~s([data-testid="group-call-prejoin-form"]))
    refute group_call_assign(view)

    group_call_prejoin(view)
  end

  defp confirm_prejoin(view, overrides \\ %{}) do
    params =
      Map.merge(
        %{
          "audio" => "true",
          "video" => "true",
          "layout_mode" => "auto",
          "self_view" => "tile",
          "sidebar_open" => "true",
          "audio_input_id" => "",
          "video_input_id" => "",
          "audio_output_id" => ""
        },
        overrides
      )

    view
    |> element(~s([data-testid="group-call-prejoin-form"]))
    |> render_submit(%{"group_call_prejoin" => params})

    flush(view)
  end

  defp open_group_call(view, overrides \\ %{}) do
    open_prejoin(view)
    confirm_prejoin(view, overrides)
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

  describe "channel group call window" do
    test "an identified channel user creates a call from the topic bar", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcfa")

      assert has_element?(view, ~s|[data-testid="group-call-open"]:not([disabled])|)

      open_prejoin(view)

      refute has_element?(view, ~s([data-testid="group-call-window"]))
      refute has_element?(view, ~s([data-testid="group-call-webrtc"]))

      confirm_prejoin(view)

      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert call.channel_name == active_channel(view)
      assert is_binary(call.join_token)
      assert call.status == :joining

      assert has_element?(
               view,
               ~s([data-testid="group-call-window"][data-window-initial-open="true"][data-window-default-maximized="true"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-taskbar"][data-window-taskbar="group-call"]),
               call.channel_name
             )

      assert has_element?(view, ~s([data-testid="status-bar-group-call"]), "Call:")

      assert has_element?(
               view,
               ~s([data-testid="group-call-webrtc"][phx-hook="GroupCallWebRTCHook"][data-group-call-token="#{call.token}"])
             )
    end

    test "pre-join cancel does not create or join a conference", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcpj")

      prejoin = open_prejoin(view)

      assert prejoin.channel_name == active_channel(view)
      assert prejoin.media.audio
      assert prejoin.media.video

      render_click(view, "group_call_prejoin_cancel", %{})
      flush(view)

      refute group_call_prejoin(view)
      refute group_call_assign(view)
      refute has_element?(view, ~s([data-testid="group-call-window"]))
      refute has_element?(view, ~s([data-testid="status-bar-group-call"]))
    end

    test "pre-join media defaults are applied to the call before WebRTC mounts", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcpk")

      open_group_call(view, %{
        "audio" => "false",
        "video" => "false",
        "layout_mode" => "focus",
        "self_view" => "hidden",
        "sidebar_open" => "false"
      })

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert call.media == %{audio: false, video: false}
      assert call.layout.mode == :focus
      assert call.layout.self_view == :hidden
      refute call.layout.sidebar_open

      assert has_element?(
               view,
               ~s([data-testid="group-call-webrtc"][data-audio="false"][data-video="false"])
             )
    end

    test "pre-join loads persisted scalar conference preferences", %{conn: conn} do
      nick = register(unique_nick("gcpp"))

      %UserPreference{}
      |> UserPreference.changeset(%{
        owner_nickname: nick.nickname,
        display_settings: %{
          "group_call_settings" => %{
            "media" => %{"audio" => false, "video" => false},
            "layout" => %{
              "mode" => "focus",
              "self_view" => "hidden",
              "sidebar_open" => false
            }
          }
        }
      })
      |> RetroHexChat.Repo.insert!()

      {:ok, view, _html} = live(chat_conn(conn, nick.nickname, pre_identified: true), "/chat")

      prejoin = open_prejoin(view)

      refute prejoin.media.audio
      refute prejoin.media.video
      assert prejoin.layout.mode == :focus
      assert prejoin.layout.self_view == :hidden
      refute prejoin.layout.sidebar_open

      refute has_element?(view, ~s([data-testid="group-call-prejoin-audio"][checked]))
      refute has_element?(view, ~s([data-testid="group-call-prejoin-video-toggle"][checked]))
    end

    test "a second identified user joins the active channel call instead of creating another",
         %{conn: conn} do
      ctx_a = mount_identified(conn, "gcfb")
      ctx_b = mount_identified(conn, "gcfc")

      assert active_channel(ctx_a.view) == active_channel(ctx_b.view)

      open_group_call(ctx_a.view)

      call_a = group_call_assign(ctx_a.view)
      cleanup_room(call_a.token)

      open_group_call(ctx_b.view)

      assert_push_event(ctx_b.view, "window_command", %{action: "open", id: "group-call"})

      call_b = group_call_assign(ctx_b.view)
      assert call_b.token == call_a.token
      assert call_b.channel_name == call_a.channel_name
    end

    test "joined channel shows a live conference indicator before entering the call", %{
      conn: conn
    } do
      ctx_a = mount_identified(conn, "gcfi")
      ctx_b = mount_identified(conn, "gcfj")
      channel = "#gcli#{uid()}"

      submit_command_sync(ctx_a.view, "/join #{channel}")
      submit_command_sync(ctx_b.view, "/join #{channel}")

      assert active_channel(ctx_a.view) == channel
      assert active_channel(ctx_b.view) == channel

      refute MapSet.member?(group_call_channels(ctx_b.view), channel)
      refute has_element?(ctx_b.view, ~s([data-testid="group-call-channel-live-badge"]))

      open_group_call(ctx_a.view)

      call_a = group_call_assign(ctx_a.view)
      cleanup_room(call_a.token)

      wait_until(fn ->
        flush(ctx_b.view)
        MapSet.member?(group_call_channels(ctx_b.view), channel)
      end)

      assert MapSet.member?(group_call_channels(ctx_b.view), channel)
      assert Map.has_key?(group_call_channel_summaries(ctx_b.view), channel)

      assert has_element?(
               ctx_b.view,
               ~s([data-testid="group-call-channel-badge"][data-channel="#{channel}"][data-state="active"]),
               "Live"
             )

      assert has_element?(
               ctx_b.view,
               ~s([data-testid="group-call-channel-popover"][data-channel="#{channel}"]),
               "Participants"
             )

      assert has_element?(ctx_b.view, ~s([data-testid="tab-group-call-glyph"]))

      assert has_element?(
               ctx_b.view,
               ~s([data-testid="channel-group-call-glyph-#{channel}"])
             )

      render_click(ctx_a.view, "group_call_close_room", %{})
      flush(ctx_a.view)
      render_click(ctx_a.view, "group_call_confirm_end_call", %{})

      assert group_call_assign(ctx_a.view) == nil

      wait_until(fn ->
        flush(ctx_b.view)
        !MapSet.member?(group_call_channels(ctx_b.view), channel)
      end)

      refute MapSet.member?(group_call_channels(ctx_b.view), channel)
      refute Map.has_key?(group_call_channel_summaries(ctx_b.view), channel)
      refute has_element?(ctx_b.view, ~s([data-testid="group-call-channel-badge"]))
      refute has_element?(ctx_b.view, ~s([data-testid="tab-group-call-glyph"]))
    end

    test "hook events populate participants and leave tears the window down", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfd")

      open_group_call(view)

      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_client_joined", %{
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
      assert has_element?(view, ~s([data-testid="group-call-participant-123"]), nick.nickname)

      render_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 123,
          "nickname" => nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => false, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      assert group_call_assign(view).status == :connected
      assert has_element?(view, ~s([data-testid="group-call-participant-123"]), "Connected")

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-123"][data-media-audio="false"][data-media-video="true"])
             )

      render_click(view, "group_call_toggle_audio", %{})
      assert_push_event(view, "group_call_set_media_state", %{audio: false, video: true})

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-123"][data-media-audio="false"][data-media-video="true"])
             )

      render_click(view, "group_call_media_state_forced", %{
        "audio" => false,
        "video" => false,
        "server_video_blocked" => true
      })

      call = group_call_assign(view)
      assert call.media.video == false
      assert call.media.server_video_blocked == true

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-123"][data-media-video="false"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-123"] [data-group-call-participant-video][data-media-moderated="true"])
             )

      assert render(view) =~ "Camera disabled by moderator"

      render_click(view, "group_call_toggle_video", %{})
      assert group_call_assign(view).media.video == false

      render_click(view, "group_call_leave", %{})
      flush(view)

      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert group_call_assign(view)

      render_click(view, "group_call_confirm_leave", %{})
      flush(view)

      assert_push_event(view, "window_command", %{action: "close", id: "group-call"})
      assert group_call_assign(view) == nil
      refute has_element?(view, ~s([data-testid="group-call-window"]))
      refute has_element?(view, ~s([data-testid="status-bar-group-call"]))
    end

    test "status bar focuses the call and stop asks for confirmation", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcff")

      open_group_call(view)

      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_statusbar_click", %{})
      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      render_click(view, "group_call_statusbar_stop", %{})
      flush(view)

      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)

      render_click(view, "group_call_confirm_cancel", %{})
      flush(view)

      assert group_call_assign(view)
    end

    test "conference layout controls update focus, self view, and participant rail", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfl")

      open_group_call(view)

      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_client_joined", %{
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

      render_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "Ada",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      assert group_call_assign(view).layout.mode == :auto
      assert has_element?(view, ~s([data-testid="group-call-layout-auto"][aria-pressed="true"]))
      assert has_element?(view, ~s([data-testid="group-call-participant-focus-456"]))

      render_click(view, "group_call_layout_mode", %{"mode" => "grid"})
      assert group_call_assign(view).layout.mode == :grid
      assert_push_event(view, "group_call_layout_state", %{mode: "grid"})

      render_click(view, "group_call_focus_participant", %{"participant-id" => "456"})
      call = group_call_assign(view)
      assert call.layout.mode == :focus
      assert call.layout.focused_participant_id == 456

      assert_push_event(view, "group_call_layout_state", %{
        mode: "focus",
        focused_participant_id: 456
      })

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-focus-456"][aria-pressed="true"])
             )

      render_click(view, "group_call_cycle_self_view", %{})
      assert group_call_assign(view).layout.self_view == :pip
      assert_push_event(view, "group_call_layout_state", %{self_view: "pip"})

      render_click(view, "group_call_toggle_sidebar", %{})
      refute group_call_assign(view).layout.sidebar_open
      assert_push_event(view, "group_call_layout_state", %{sidebar_open: false})
      refute has_element?(view, ~s([data-testid="group-call-participants"]))
    end

    test "advanced layouts follow speaker state and pin participants", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcsp")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_client_joined", %{
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

      render_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "Ada",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      render_click(view, "group_call_participant_quality", %{
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

      render_click(view, "group_call_layout_mode", %{"mode" => "speaker"})

      call = group_call_assign(view)
      assert call.layout.mode == :speaker
      assert call.layout.focused_participant_id == 456

      assert has_element?(
               view,
               ~s([data-testid="group-call-layout-speaker"][aria-pressed="true"])
             )

      assert_push_event(view, "group_call_layout_state", %{
        mode: "speaker",
        focused_participant_id: 456
      })

      render_click(view, "group_call_toggle_pin_participant", %{"participant-id" => "456"})

      assert group_call_assign(view).layout.pinned_participant_ids == [456]

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-pin-456"][aria-pressed="true"])
             )

      assert_push_event(view, "group_call_layout_state", %{
        pinned_participant_ids: [456]
      })

      render_click(view, "group_call_toggle_pin_participant", %{"participant-id" => "456"})

      assert group_call_assign(view).layout.pinned_participant_ids == []

      assert has_element?(
               view,
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

      render_click(view, "group_call_client_joined", %{
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

      render_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "Ada",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      render_click(view, "shortcut_action", %{"action" => "group_call_toggle_audio"})
      assert_push_event(view, "group_call_set_media_state", %{audio: false, video: true})
      refute group_call_assign(view).media.audio

      render_click(view, "window_keydown", %{
        "key" => "ArrowLeft",
        "ctrlKey" => true,
        "shiftKey" => true,
        "altKey" => false
      })

      assert_push_event(view, "group_call_set_media_state", %{audio: false, video: false})
      refute group_call_assign(view).media.video

      render_click(view, "shortcut_action", %{"action" => "group_call_layout_next"})
      assert group_call_assign(view).layout.mode == :grid
      assert_push_event(view, "group_call_layout_state", %{mode: "grid"})

      render_click(view, "shortcut_action", %{"action" => "group_call_focus_next"})
      call = group_call_assign(view)
      assert call.layout.mode == :focus
      assert call.layout.focused_participant_id == 456

      assert_push_event(view, "group_call_layout_state", %{
        mode: "focus",
        focused_participant_id: 456
      })

      render_click(view, "shortcut_action", %{"action" => "group_call_leave"})
      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)
    end

    test "conference exposes keyboard and screen-reader semantics", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcax")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert has_element?(
               view,
               ~s([data-testid="group-call-panel"][role="region"][aria-label="Channel conference"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-webrtc"][role="region"][aria-label="Conference media"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-layout-controls"][role="toolbar"][aria-label="Conference layout controls"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-reactions"][role="toolbar"][aria-label="Conference reactions"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-remote-placeholder"][role="status"][aria-live="polite"])
             )

      render_click(view, "group_call_client_joined", %{
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
               view,
               ~s([data-testid="group-call-participants"][role="list"][aria-label="Conference participant list"])
             )

      assert has_element?(view, ~s([data-testid="group-call-participant-123"][role="listitem"]))

      render_click(view, "group_call_client_warning", %{
        "message" => "Network quality degraded."
      })

      assert has_element?(
               view,
               ~s([data-testid="group-call-warning"][role="status"][aria-live="polite"]),
               "Network quality degraded."
             )

      render_click(view, "group_call_client_error", %{
        "message" => "Media connection failed."
      })

      assert has_element?(
               view,
               ~s([data-testid="group-call-error"][role="alert"][aria-live="assertive"]),
               "Media connection failed."
             )
    end

    test "conference renders rich empty and failure states with clear actions", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcef")

      open_group_call(view, %{"audio" => "false", "video" => "false"})

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert has_element?(
               view,
               ~s([data-testid="group-call-remote-placeholder"]),
               "Waiting for participants"
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-local-empty"]),
               "Receive-only mode"
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-participants-loading"][role="listitem"]),
               "Joining conference"
             )

      render_click(view, "group_call_client_warning", %{
        "message" => "Could not access your microphone or camera. You joined receive-only."
      })

      assert has_element?(
               view,
               ~s([data-testid="group-call-warning-title"]),
               "Media warning"
             )

      assert has_element?(view, ~s([data-testid="group-call-warning"]), "receive-only")

      render_click(view, "group_call_recovery_state", %{
        "state" => "failed",
        "manual_retry" => true,
        "attempt" => 3,
        "max_attempts" => 3,
        "message" => "Media recovery failed. Retry the media connection."
      })

      assert has_element?(
               view,
               ~s([data-testid="group-call-error-title"]),
               "Connection needs attention"
             )

      assert has_element?(view, ~s([data-testid="group-call-retry"]))
      assert has_element?(view, ~s([data-testid="group-call-leave-from-error"]))

      view
      |> element(~s([data-testid="group-call-leave-from-error"]))
      |> render_click()

      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)
    end

    test "mini mode keeps the WebRTC surface mounted with compact controls", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcmi")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert has_element?(
               view,
               ~s([data-testid="group-call-webrtc"][data-group-call-token="#{call.token}"])
             )

      view
      |> element(~s([data-testid="group-call-mini-toggle"]))
      |> render_click()

      assert_push_event(view, "group_call_layout_state", %{mini: true})
      assert group_call_assign(view).layout.mini == true
      assert has_element?(view, ~s([data-testid="group-call-panel"][data-mini-mode="true"]))

      assert has_element?(
               view,
               ~s([data-testid="group-call-webrtc"][data-group-call-token="#{call.token}"])
             )

      refute has_element?(view, ~s([data-testid="group-call-participants"]))
      assert has_element?(view, ~s([data-testid="group-call-mini-audio-toggle"]))
      assert has_element?(view, ~s([data-testid="group-call-mini-video-toggle"]))
      assert has_element?(view, ~s([data-testid="group-call-mini-leave"]))
      assert has_element?(view, ~s([data-testid="group-call-mini-expand"]))

      view
      |> element(~s([data-testid="group-call-mini-audio-toggle"]))
      |> render_click()

      assert_push_event(view, "group_call_set_media_state", %{audio: false, video: true})

      view
      |> element(~s([data-testid="group-call-mini-expand"]))
      |> render_click()

      assert_push_event(view, "group_call_layout_state", %{mini: false})
      assert group_call_assign(view).layout.mini == false
      assert has_element?(view, ~s([data-testid="group-call-panel"][data-mini-mode="false"]))
    end

    test "stats section renders inside the conference console", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcst")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      view
      |> element(~s([data-testid="group-call-section-stats"]))
      |> render_click()

      assert group_call_assign(view).layout.console_section == :stats
      assert has_element?(view, ~s([data-testid="group-call-inline-stats"]))

      assert has_element?(
               view,
               ~s([data-testid="group-call-inline-stats"] [data-testid="group-call-stats-panel"])
             )
    end

    test "browser stats update the inline conference statistics section", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcfs")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_stats", %{
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

      view
      |> element(~s([data-testid="group-call-section-stats"]))
      |> render_click()

      assert group_call_assign(view).layout.console_section == :stats
      assert has_element?(view, ~s([data-testid="group-call-inline-stats"]))
      assert has_element?(view, ~s([data-testid="group-call-stats-summary"]))
      assert has_element?(view, ~s([data-testid="group-call-stats-summary-health"]), "Good")
      assert has_element?(view, ~s([data-testid="group-call-stats-summary-latency"]), "42 ms")
      assert has_element?(view, ~s([data-testid="group-call-stats-details-browser-connection"]))
      assert has_element?(view, ~s([data-testid="group-call-stats-details-audio"]))
      assert has_element?(view, ~s([data-testid="group-call-stats-details-video"]))
      assert has_element?(view, ~s([data-testid="group-call-stats-details-browser-summary"]))

      assert has_element?(
               view,
               ~s([data-testid="group-call-stats-summary-media"]),
               "Audio + Video"
             )

      assert has_element?(view, ~s([data-testid="group-call-stats-health"]), "Good")
      assert render(view) =~ "1280x720"
    end

    test "screen share state updates controls, participant state, focus, and stats", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcsh")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_client_joined", %{
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

      render_click(view, "group_call_screen_share_state", %{
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
               view,
               ~s([data-testid="group-call-screen-share-toggle"][aria-pressed="true"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-123"][data-media-screen="true"])
             )

      view
      |> element(~s([data-testid="group-call-section-stats"]))
      |> render_click()

      assert has_element?(view, ~s([data-testid="group-call-inline-stats"]))
      assert render(view) =~ "Screen tracks"

      render_click(view, "group_call_screen_share_state", %{
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
               view,
               ~s([data-testid="group-call-screen-share-toggle"][aria-pressed="false"])
             )
    end

    test "participant quality state renders active speaker and quality badges", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcql")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_client_joined", %{
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
               view,
               ~s([data-testid="group-call-participant-quality-456"])
             )

      render_click(view, "group_call_participant_quality", %{
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
               view,
               ~s([data-testid="group-call-participant-456"][data-active-speaker="true"][data-quality-level="poor"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-quality-456"][data-quality-level="poor"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-active-speaker-456"])
             )

      assert render(view) =~ "RTT 260 ms"
    end

    test "conference reactions render on participant rows without chat spam", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcrx")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_client_joined", %{
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
                 view,
                 ~s([data-testid="group-call-reaction-icon-#{reaction}"] svg)
               )
      end

      html = render(view)
      refute html =~ "👍"
      refute html =~ "👏"
      refute html =~ "😄"
      refute html =~ "✨"

      render_click(view, "group_call_reaction", %{
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
               view,
               ~s([data-testid="group-call-participant-reaction-456"][data-reaction="clap"])
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-participant-reaction-icon-456"] svg)
             )

      html = render(view)
      refute html =~ "👏"
    end

    test "server stats from the SFU summary render beside browser stats", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfr")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_client_joined", %{
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

      view
      |> element(~s([data-testid="group-call-section-stats"]))
      |> render_click()

      html = render(view)
      assert html =~ "Server runtime"
      assert html =~ ~s(data-testid="group-call-stats-details-server-runtime")
      assert html =~ ~s(data-testid="group-call-stats-details-server-peers")
      assert html =~ "Server peers"
      assert html =~ "1/1 connected"
      assert html =~ "12 pkt / 2.0 KB"
      assert html =~ "24 pkt / 4.0 KB"
      assert html =~ "NACK 1 / PLI 2"
      assert html =~ "connected / ICE completed"
      assert html =~ "2 in / 3 fanout"
      assert html =~ "2 trk / 15 pkt / 3.0 KB"
      assert html =~ "6 trk / 30 pkt / 6.0 KB"
      assert html =~ "1/4 nominated / 2 valid"
      assert html =~ "4.0 KB up / 8.0 KB down"
      assert html =~ "NACK 3 / PLI 3"
    end

    test "media warnings stay recoverable while failed connection becomes actionable error", %{
      conn: conn
    } do
      %{view: view} = mount_identified(conn, "gcfw")

      open_group_call(view)

      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_client_warning", %{
        "code" => "media_capture_failed",
        "message" => "Could not access your microphone or camera. You joined receive-only."
      })

      call = group_call_assign(view)
      assert call.status == :joining

      assert call.warning ==
               "Could not access your microphone or camera. You joined receive-only."

      refute call.error

      assert has_element?(
               view,
               ~s([data-testid="group-call-warning"]),
               "receive-only"
             )

      render_click(view, "group_call_connection_state", %{"state" => "disconnected"})

      call = group_call_assign(view)
      assert call.connection_state == "disconnected"
      assert call.status == :reconnecting
      assert call.warning =~ "Trying to recover"
      refute call.error

      render_click(view, "group_call_connection_state", %{"state" => "failed"})

      call = group_call_assign(view)
      assert call.status == :error
      assert call.connection_state == "failed"
      assert call.error =~ "Retry the media connection"
      refute call.warning

      assert has_element?(view, ~s([data-testid="group-call-error"]), "Retry")
      refute has_element?(view, ~s([data-testid="group-call-warning"]))

      render_click(view, "group_call_recovery_state", %{
        "state" => "failed",
        "manual_retry" => true,
        "attempt" => 3,
        "max_attempts" => 3,
        "message" => "Media recovery failed. Retry the media connection."
      })

      call = group_call_assign(view)
      assert call.recovery.state == :failed
      assert call.recovery.manual_retry

      assert has_element?(view, ~s([data-testid="group-call-retry"]))

      view
      |> element(~s([data-testid="group-call-retry"]))
      |> render_click()

      assert_push_event(view, "group_call_retry_media", %{trigger: "manual"})
    end

    test "moderators see call and participant moderation controls", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfm")

      open_group_call(view)

      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_client_joined", %{
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

      render_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "TargetUser",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      assert has_element?(view, ~s([data-testid="group-call-close-room"]))
      assert has_element?(view, ~s([data-testid="group-call-participant-audio-moderate-456"]))
      assert has_element?(view, ~s([data-testid="group-call-participant-video-moderate-456"]))
      assert has_element?(view, ~s([data-testid="group-call-participant-kick-456"]))
      refute has_element?(view, ~s([data-testid="group-call-participant-kick-123"]))

      render_click(view, "group_call_close_room", %{})
      flush(view)

      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)

      render_click(view, "group_call_confirm_cancel", %{})
      flush(view)

      assert group_call_assign(view)
    end

    test "participant moderation buttons follow the channel permission matrix", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcpm")

      open_group_call(view)

      call = group_call_assign(view)
      cleanup_room(call.token)

      roles = ["owner", "operator", "half_operator", "voiced", "regular"]

      for actor_role <- roles, target_role <- roles do
        render_click(view, "group_call_client_joined", %{
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

        render_click(view, "group_call_peer_joined", %{
          "participant" => %{
            "id" => 456,
            "nickname" => "TargetUser",
            "status" => "connected",
            "media_state" => %{"audio" => true, "video" => true},
            "channel_role_snapshot" => target_role
          }
        })

        if actor_role in ["owner", "operator", "half_operator"] do
          assert has_element?(view, ~s([data-testid="group-call-close-room"]))
        else
          refute has_element?(view, ~s([data-testid="group-call-close-room"]))
        end

        if ui_can_moderate?(actor_role, target_role) do
          assert has_element?(
                   view,
                   ~s([data-testid="group-call-participant-audio-moderate-456"])
                 )

          assert has_element?(
                   view,
                   ~s([data-testid="group-call-participant-video-moderate-456"])
                 )
        else
          refute has_element?(
                   view,
                   ~s([data-testid="group-call-participant-audio-moderate-456"])
                 )

          refute has_element?(
                   view,
                   ~s([data-testid="group-call-participant-video-moderate-456"])
                 )
        end

        if ui_can_remove?(actor_role, target_role) do
          assert has_element?(view, ~s([data-testid="group-call-participant-kick-456"]))
        else
          refute has_element?(view, ~s([data-testid="group-call-participant-kick-456"]))
        end
      end

      render_click(view, "group_call_client_joined", %{
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

      render_click(view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => "RoleMissing",
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => nil
        }
      })

      refute has_element?(view, ~s([data-testid="group-call-participant-audio-moderate-456"]))
      refute has_element?(view, ~s([data-testid="group-call-participant-video-moderate-456"]))
      refute has_element?(view, ~s([data-testid="group-call-participant-kick-456"]))
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

      render_click(moderator.view, "group_call_client_joined", %{
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

      render_click(moderator.view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => target_payload.participant.id,
          "nickname" => target.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      moderator.view
      |> element(~s([data-testid="group-call-mute-all"]))
      |> render_click()

      flush(moderator.view)
      assert has_element?(moderator.view, ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert render(moderator.view) =~ "Mute all lower-ranked participants"

      render_click(moderator.view, "group_call_confirm_mute_all", %{})
      flush(moderator.view)

      muted_call = group_call_assign(moderator.view)
      muted_target = Enum.find(muted_call.participants, &(&1.id == target_payload.participant.id))

      assert muted_target.media_state.audio == false
      assert muted_target.media_state.server_audio_muted == true
      assert render(moderator.view) =~ "muted 1 conference microphone"

      moderator.view
      |> element(~s([data-testid="group-call-camera-off-all"]))
      |> render_click()

      flush(moderator.view)
      assert has_element?(moderator.view, ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert render(moderator.view) =~ "Turn off cameras for all lower-ranked participants"

      render_click(moderator.view, "group_call_confirm_camera_off_all", %{})
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

      render_click(view, "group_call_client_joined", %{
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

      render_click(view, "group_call_toggle_lock", %{})

      flush(view)

      assert group_call_assign(view).room.metadata["locked"] == true
      assert render(view) =~ "locked the conference"

      render_click(view, "group_call_toggle_lock", %{})

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

      call = group_call_assign(moderator.view)
      cleanup_room(call.token)

      moderator_payload = join_runtime_group_call(call, moderator.nick)
      target_payload = join_runtime_group_call(call, target)

      render_click(moderator.view, "group_call_client_joined", %{
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

      render_click(moderator.view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => target_payload.participant.id,
          "nickname" => target.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      moderator.view
      |> element(~s([data-testid="group-call-hand-toggle"]))
      |> render_click()

      self_call = group_call_assign(moderator.view)
      assert self_call.media.hand_raised == true

      render_click(moderator.view, "group_call_toggle_hand", %{})
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

      render_click(moderator.view, "group_call_media_state", %{
        "participant" => %{
          "id" => raised.id,
          "nickname" => raised.nickname,
          "status" => raised.status,
          "media_state" => raised.media_state,
          "channel_role_snapshot" => raised.channel_role_snapshot
        }
      })

      assert muted.media_state["server_audio_muted"] == true
      assert has_element?(moderator.view, ~s([data-testid="group-call-raised-hand-queue"]))

      assert has_element?(
               moderator.view,
               ~s([data-testid="group-call-queue-allow-speak-#{target_payload.participant.id}"])
             )

      moderator.view
      |> element(
        ~s([data-testid="group-call-queue-allow-speak-#{target_payload.participant.id}"])
      )
      |> render_click()

      allowed = Queries.get_participant(target_payload.participant.id)
      assert allowed.media_state["audio"] == true
      assert allowed.media_state["server_audio_muted"] == false
      assert allowed.media_state["hand_raised"] == false

      refute has_element?(
               moderator.view,
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

      call = group_call_assign(moderator.view)
      cleanup_room(call.token)

      moderator_payload = join_runtime_group_call(call, moderator.nick)
      target_payload = join_runtime_group_call(call, target)
      mark_runtime_ready(call, moderator_payload)
      mark_runtime_ready(call, target_payload)
      flush(moderator.view)

      render_click(moderator.view, "group_call_client_joined", %{
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

      render_click(moderator.view, "group_call_screen_share_state", %{
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
               moderator.view,
               ~s([data-testid="group-call-participant-screen-moderate-#{target_payload.participant.id}"])
             )

      moderator.view
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

      moderator.view
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

      mod_call = group_call_assign(moderator.view)
      cleanup_room(mod_call.token)

      open_group_call(target.view)

      assert group_call_assign(target.view).token == mod_call.token

      for {ctx, id, role} <- [{moderator, 123, "owner"}, {target, 456, "regular"}] do
        render_click(ctx.view, "group_call_client_joined", %{
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

      render_click(moderator.view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => target.nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      moderator.view
      |> element(~s([data-testid="group-call-participant-kick-456"]))
      |> render_click()

      flush(moderator.view)
      assert has_element?(moderator.view, ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert render(moderator.view) =~ "prevent them from rejoining"

      render_click(moderator.view, "group_call_confirm_kick_participant", %{})
      flush(moderator.view)
      flush(target.view)

      assert render(moderator.view) =~ "banned from #{channel}"
      refute has_element?(moderator.view, ~s([data-testid="group-call-participant-456"]))
      assert group_call_assign(target.view) == nil
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
        render_click(ctx.view, "group_call_client_joined", %{
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

      render_click(half.view, "group_call_peer_joined", %{
        "participant" => %{
          "id" => 456,
          "nickname" => target.nick.nickname,
          "status" => "connected",
          "media_state" => %{"audio" => true, "video" => true},
          "channel_role_snapshot" => "regular"
        }
      })

      refute has_element?(half.view, ~s([data-testid="group-call-participant-kick-456"]))

      render_click(half.view, "group_call_kick_participant", %{"participant-id" => "456"})
      flush(half.view)

      refute has_element?(half.view, ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert render(half.view) =~ "Insufficient privileges"
      assert group_call_assign(target.view)
      assert channel in :sys.get_state(target.view.pid).socket.assigns.session.channels
    end

    test "opening Call in another channel asks before switching conferences", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcfg")

      open_group_call(view)

      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      first_call = group_call_assign(view)
      cleanup_room(first_call.token)

      channel = "#gcsw#{uid()}"
      submit_command_sync(view, "/join #{channel}")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

      flush(view)

      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert group_call_assign(view).token == first_call.token

      render_click(view, "group_call_confirm_switch", %{})
      assert_push_event(view, "window_command", %{action: "close", id: "group-call"})
      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      switched_call = group_call_assign(view)
      cleanup_room(switched_call.token)

      assert switched_call.token != first_call.token
      assert switched_call.channel_name == channel
    end

    test "an unidentified user sees the channel control disabled", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, unique_nick("gcfe")), "/chat")

      assert has_element?(view, ~s([data-testid="group-call-open"][disabled]))

      render_click(view, "group_call_open", %{})
      refute group_call_assign(view)
      assert render(view) =~ "identified with NickServ"
    end
  end
end
