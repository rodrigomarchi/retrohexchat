defmodule RetroHexChatWeb.ChatLive.GroupCallFlowTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

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
      assert group_call_assign(view) == nil
      refute has_element?(view, ~s([data-testid="group-call-window"]))
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
