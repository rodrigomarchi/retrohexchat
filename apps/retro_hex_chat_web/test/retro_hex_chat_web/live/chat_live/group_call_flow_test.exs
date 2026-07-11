defmodule RetroHexChatWeb.ChatLive.GroupCallFlowTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.GroupCall.Registry
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
  defp active_channel(view), do: :sys.get_state(view.pid).socket.assigns.session.active_channel
  defp flush(view), do: :sys.get_state(view.pid)

  defp cleanup_room(token) do
    on_exit(fn ->
      case Registry.lookup_room({:room, token}) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end
    end)
  end

  describe "channel group call window" do
    test "an identified channel user creates a call from the topic bar", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcfa")

      assert has_element?(view, ~s|[data-testid="group-call-open"]:not([disabled])|)

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

      assert_push_event(view, "window_command", %{action: "open", id: "group-call-stats"})
      assert_push_event(view, "window_command", %{action: "minimize", id: "group-call-stats"})
      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      call = group_call_assign(view)
      cleanup_room(call.token)

      assert call.channel_name == active_channel(view)
      assert is_binary(call.join_token)
      assert call.status == :joining

      assert has_element?(
               view,
               ~s([data-testid="group-call-window"][data-window-initial-open="true"])
             )

      assert has_element?(view, ~s([data-testid="group-call-stats-window"]))

      assert has_element?(
               view,
               ~s([data-testid="group-call-taskbar"][data-window-taskbar="group-call"]),
               call.channel_name
             )

      assert has_element?(
               view,
               ~s([data-testid="group-call-stats-taskbar"][data-window-taskbar="group-call-stats"]),
               "Conference Statistics"
             )

      assert has_element?(view, ~s([data-testid="status-bar-group-call"]), "Call:")

      assert has_element?(
               view,
               ~s([data-testid="group-call-webrtc"][phx-hook="GroupCallWebRTCHook"][data-group-call-token="#{call.token}"])
             )
    end

    test "a second identified user joins the active channel call instead of creating another",
         %{conn: conn} do
      ctx_a = mount_identified(conn, "gcfb")
      ctx_b = mount_identified(conn, "gcfc")

      assert active_channel(ctx_a.view) == active_channel(ctx_b.view)

      ctx_a.view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

      call_a = group_call_assign(ctx_a.view)
      cleanup_room(call_a.token)

      ctx_b.view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

      assert_push_event(ctx_b.view, "window_command", %{action: "open", id: "group-call"})

      call_b = group_call_assign(ctx_b.view)
      assert call_b.token == call_a.token
      assert call_b.channel_name == call_a.channel_name
    end

    test "hook events populate participants and leave tears the window down", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfd")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

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

      render_click(view, "group_call_leave", %{})
      flush(view)

      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert group_call_assign(view)

      render_click(view, "group_call_confirm_leave", %{})
      flush(view)

      assert_push_event(view, "window_command", %{action: "close", id: "group-call"})
      assert_push_event(view, "window_command", %{action: "close", id: "group-call-stats"})
      assert group_call_assign(view) == nil
      refute has_element?(view, ~s([data-testid="group-call-window"]))
      refute has_element?(view, ~s([data-testid="group-call-stats-window"]))
      refute has_element?(view, ~s([data-testid="status-bar-group-call"]))
    end

    test "status bar focuses the call and stop asks for confirmation", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcff")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

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

    test "closing the statistics window asks before leaving the conference", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcfx")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

      assert_push_event(view, "window_command", %{action: "open", id: "group-call"})

      call = group_call_assign(view)
      cleanup_room(call.token)

      render_click(view, "group_call_window_close", %{"id" => "group-call-stats"})
      flush(view)

      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert group_call_assign(view)
      assert has_element?(view, ~s([data-testid="group-call-stats-window"]))

      render_click(view, "group_call_confirm_cancel", %{})
      flush(view)

      assert_push_event(view, "window_command", %{action: "open", id: "group-call-stats"})
      assert group_call_assign(view)

      render_hook(view, "window_closed", %{"id" => "group-call-stats"})
      flush(view)

      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)
      assert group_call_assign(view)

      render_click(view, "group_call_confirm_leave", %{})
      flush(view)

      assert_push_event(view, "window_command", %{action: "close", id: "group-call"})
      assert_push_event(view, "window_command", %{action: "close", id: "group-call-stats"})
      assert group_call_assign(view) == nil
      refute has_element?(view, ~s([data-testid="group-call-window"]))
      refute has_element?(view, ~s([data-testid="group-call-stats-window"]))
    end

    test "conference layout controls update focus, self view, and participant rail", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfl")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

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

    test "browser stats update the conference statistics window", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcfs")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

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

      assert has_element?(view, ~s([data-testid="group-call-stats-window"]))
      assert has_element?(view, ~s([data-testid="group-call-stats-health"]), "Good")
      assert render(view) =~ "1280x720"
    end

    test "server stats from the SFU summary render beside browser stats", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfr")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

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
          }
        }
      })

      call = group_call_assign(view)
      assert call.server_stats.totals.inbound_bytes == 2048
      assert call.server_stats.totals.outbound_peer_count == 3

      html = render(view)
      assert html =~ "Server runtime"
      assert html =~ "1/1 connected"
      assert html =~ "12 pkt / 2.0 KB"
      assert html =~ "24 pkt / 4.0 KB"
      assert html =~ "NACK 1 / PLI 2"
    end

    test "media warnings stay recoverable while failed connection becomes actionable error", %{
      conn: conn
    } do
      %{view: view} = mount_identified(conn, "gcfw")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

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
      assert call.warning =~ "Trying to recover"
      refute call.error

      render_click(view, "group_call_connection_state", %{"state" => "failed"})

      call = group_call_assign(view)
      assert call.status == :error
      assert call.connection_state == "failed"
      assert call.error =~ "Leave and rejoin"
      refute call.warning

      assert has_element?(view, ~s([data-testid="group-call-error"]), "Leave and rejoin")
      refute has_element?(view, ~s([data-testid="group-call-warning"]))
    end

    test "moderators see call and participant moderation controls", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfm")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

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
      assert has_element?(view, ~s([data-testid="group-call-participant-kick-456"]))
      refute has_element?(view, ~s([data-testid="group-call-participant-kick-123"]))

      render_click(view, "group_call_close_room", %{})
      flush(view)

      assert has_element?(view, ~s|#group-call-confirm-dialog:not(.hidden)|)

      render_click(view, "group_call_confirm_cancel", %{})
      flush(view)

      assert group_call_assign(view)
    end

    test "confirmed participant removal bans from channel and closes target conference", %{
      conn: conn
    } do
      moderator = mount_identified(conn, "gckm")
      target = mount_identified(conn, "gckt")
      channel = "#gck#{uid()}"

      submit_command_sync(moderator.view, "/join #{channel}")
      submit_command_sync(target.view, "/join #{channel}")

      moderator.view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

      mod_call = group_call_assign(moderator.view)
      cleanup_room(mod_call.token)

      target.view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

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

    test "opening Call in another channel asks before switching conferences", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcfg")

      view
      |> element(~s([data-testid="group-call-open"]))
      |> render_click()

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
