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
    :timer.sleep(5)
  end

  defp send_new_pm(view, sender, recipient, content) do
    msg = %{
      event: "new_pm",
      payload: %{
        id: "pm-#{uid()}",
        sender: sender,
        recipient: recipient,
        content: content,
        type: :message,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
    :timer.sleep(5)
  end

  defp send_user_joined(view, nick, channel) do
    send(view.pid, {:user_joined, %{nickname: nick, role: :regular, channel: channel}})
    :timer.sleep(5)
  end

  defp send_user_left(view, nick, channel) do
    send(view.pid, {:user_left, %{nickname: nick, reason: nil, channel: channel}})
    :timer.sleep(5)
  end

  defp send_user_kicked(view, operator, target) do
    send(view.pid, {:user_kicked, %{operator: operator, target: target, reason: "bye"}})
    :timer.sleep(5)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  # ── Connect sound ───────────────────────────────────────────

  describe "connect sound on mount" do
    test "play_sound with connect sound on successful mount", %{conn: conn} do
      nick = "SndCon#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      assert_push_event(view, "play_sound", %{type: "chime_short"})
    end
  end

  # ── Highlight sound ─────────────────────────────────────────

  describe "highlight sound dispatch" do
    test "highlight plays alert sound (default)", %{conn: conn} do
      nick = "SndHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      # Consume connect sound
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_new_message(view, "Other", "hey #{nick}!", "#lobby")

      assert_push_event(view, "play_sound", %{type: "alert"})
    end

    test "non-highlight message in active channel produces no sound", %{conn: conn} do
      nick = "SndNoHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_new_message(view, "Other", "hello world", "#lobby")

      render(view)
      refute_push_event(view, "play_sound", %{})
    end
  end

  # ── Message sound (non-active channel) ──────────────────────

  describe "message sound for non-active channel" do
    test "non-highlight message in background channel plays ding_low", %{conn: conn} do
      nick = "SndBG#{uid()}"
      ch = "#snd_bg_#{uid()}"
      ensure_channel(ch)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      # Join second channel and switch back to #lobby
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/join #{ch}"})

      view
      |> element(~s(div[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Send message to background channel (not highlighted)
      send_new_message(view, "Other", "background message", ch)

      assert_push_event(view, "play_sound", %{type: "ding_low"})
    end
  end

  # ── PM sound ────────────────────────────────────────────────

  describe "PM sound dispatch" do
    test "PM from non-active conversation plays chime_high", %{conn: conn} do
      nick = "SndPM#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_new_pm(view, "Alice", nick, "hey there")

      assert_push_event(view, "play_sound", %{type: "chime_high"})
    end
  end

  # ── Join/Part/Kick sounds ───────────────────────────────────

  describe "join/part/kick sound dispatch" do
    test "user_joined plays click sound", %{conn: conn} do
      nick = "SndJoin#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_user_joined(view, "NewUser", "#lobby")

      assert_push_event(view, "play_sound", %{type: "click"})
    end

    test "user_left plays click sound", %{conn: conn} do
      nick = "SndPart#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_user_left(view, "LeavingUser", "#lobby")

      assert_push_event(view, "play_sound", %{type: "click"})
    end

    test "user_kicked plays buzz sound", %{conn: conn} do
      nick = "SndKick#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_user_kicked(view, "Operator", "KickedUser")

      assert_push_event(view, "play_sound", %{type: "buzz"})
    end
  end
end
