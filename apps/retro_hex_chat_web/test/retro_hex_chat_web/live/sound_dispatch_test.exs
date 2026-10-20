defmodule RetroHexChatWeb.SoundDispatchTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :liveview

  # ── Helpers ──────────────────────────────────────────────────

  defp send_new_message(view, author, content, channel) do
    msg = %{
      event: "new_message",
      payload: %{
        id: "msg-#{uid()}",
        author: author,
        content: content,
        type: :message,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)

    # Flush the async send_update from the message/membership stream islands so
    # any push_event from this handler is delivered before the caller asserts.
    render(view)
  end

  defp send_pm_activity(view, sender, recipient, content) do
    send(
      view.pid,
      %{
        event: "new_pm",
        payload: %{
          id: System.unique_integer([:positive]),
          sender: sender,
          recipient: recipient,
          content: content,
          type: :message,
          timestamp: DateTime.utc_now(),
          peer: sender,
          direction: :incoming
        }
      }
    )

    # Flush the async send_update from the message/membership stream islands so
    # any push_event from this handler is delivered before the caller asserts.
    render(view)
  end

  defp send_user_joined(view, nick, channel) do
    send(view.pid, {:user_joined, %{nickname: nick, role: :regular, channel: channel}})
    # Flush the async send_update from the message/membership stream islands so
    # any push_event from this handler is delivered before the caller asserts.
    render(view)
  end

  defp send_user_left(view, nick, channel) do
    send(view.pid, {:user_left, %{nickname: nick, reason: nil, channel: channel}})
    # Flush the async send_update from the message/membership stream islands so
    # any push_event from this handler is delivered before the caller asserts.
    render(view)
  end

  defp send_user_kicked(view, operator, target) do
    send(view.pid, {:user_kicked, %{operator: operator, target: target, reason: "bye"}})
    # Flush the async send_update from the message/membership stream islands so
    # any push_event from this handler is delivered before the caller asserts.
    render(view)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  # Every test mounts a fresh chat and first consumes the connect sound, so
  # each also proves that a successful mount plays chime_short.
  defp mount_chat(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/")
    assert_push_event(view, "play_sound", %{type: "chime_short"})
    view
  end

  # ── Active channel: highlight vs plain message ──────────────

  describe "messages in the active channel" do
    test "a plain message is silent and a highlight plays alert (default)", %{conn: conn} do
      nick = "SndHL#{uid()}"
      view = mount_chat(conn, nick)

      send_new_message(view, "Other", "hello world", "#lobby")
      refute_push_event(view, "play_sound", %{})

      send_new_message(view, "Other", "hey #{nick}!", "#lobby")
      assert_push_event(view, "play_sound", %{type: "alert"})
    end
  end

  # ── Message sound (non-active channel) ──────────────────────

  describe "message sound for non-active channel" do
    test "non-highlight message in background channel plays ding_low", %{conn: conn} do
      nick = "SndBG#{uid()}"
      ch = "#snd_bg_#{uid()}"
      ensure_channel(ch)

      view = mount_chat(conn, nick)

      # Join second channel and switch back to #lobby
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/join #{ch}"})

      render_click(view, "switch_channel", %{"channel" => "#lobby"})

      # Send message to background channel (not highlighted)
      send_new_message(view, "Other", "background message", ch)

      assert_push_event(view, "play_sound", %{type: "ding_low"})
    end
  end

  # ── PM and join/part/kick sounds ────────────────────────────

  # Each event is sent and its sound asserted before the next, so a sound
  # can only be the one its own event produced.
  describe "PM and join/part/kick sound dispatch" do
    test "a PM plays chime_high; join and part play click; a kick plays buzz", %{conn: conn} do
      nick = "SndEvt#{uid()}"
      view = mount_chat(conn, nick)

      send_pm_activity(view, "Alice", nick, "hey there")
      assert_push_event(view, "play_sound", %{type: "chime_high"})

      send_user_joined(view, "NewUser", "#lobby")
      assert_push_event(view, "play_sound", %{type: "click"})

      send_user_left(view, "LeavingUser", "#lobby")
      assert_push_event(view, "play_sound", %{type: "click"})

      send_user_kicked(view, "Operator", "KickedUser")
      assert_push_event(view, "play_sound", %{type: "buzz"})

      refute_push_event(view, "play_sound", %{})
    end
  end
end
