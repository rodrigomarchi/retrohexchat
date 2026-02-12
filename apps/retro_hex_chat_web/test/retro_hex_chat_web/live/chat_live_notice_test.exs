defmodule RetroHexChatWeb.ChatLiveNoticeTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ── US1: Send a Notice to a User ───────────────────────────────

  describe "US1: sending /notice to an online user" do
    test "broadcasts {:new_notice, payload} to user topic", %{conn: conn} do
      sender = "NtcSnd#{System.unique_integer([:positive])}"
      receiver = "NtcRcv#{System.unique_integer([:positive])}"

      # Connect both users
      {:ok, _recv_view, _html} = live(conn, "/chat?nickname=#{receiver}")
      {:ok, send_view, _html} = live(conn, "/chat?nickname=#{sender}")

      # Subscribe to receiver's topic to verify broadcast
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{receiver}")

      send_view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice #{receiver} hey there"})

      assert_receive {:new_notice, payload}, 1000
      assert payload.sender == sender
      assert payload.content == "hey there"
      assert %DateTime{} = payload.timestamp
    end

    test "shows error when target user is not online", %{conn: conn} do
      nick = "NtcErr#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice OfflineUser hello"})

      html = render(view)
      assert html =~ "not found"
    end
  end

  describe "US1: receiving a notice" do
    test "renders notice with -Nick- prefix and .chat-notice class", %{conn: conn} do
      nick = "NtcRdr#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_notice(view, "Bob", "hey there")

      html = render(view)
      assert html =~ "-Bob-"
      assert html =~ "hey there"
      assert html =~ "chat-notice"
    end

    test "notice from ignored user is silently dropped", %{conn: conn} do
      nick = "NtcIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Ignore the sender
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot"})

      send_notice(view, "SpamBot", "you should not see this notice")

      html = render(view)
      refute html =~ "you should not see this notice"
    end

    test "notice from user ignored with :notices type is dropped", %{conn: conn} do
      nick = "NtcIgnT#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Ignore only notices from sender
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot notices"})

      send_notice(view, "SpamBot", "hidden notice content")

      html = render(view)
      refute html =~ "hidden notice content"
    end

    test "notice does NOT trigger play_sound event", %{conn: conn} do
      nick = "NtcSnd2#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
      # Consume connect sound event
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_notice(view, "Bob", "quiet notice")

      refute_push_event(view, "play_sound", %{})
    end

    test "notice does NOT create PM window or treebar entry", %{conn: conn} do
      nick = "NtcNoPm#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_notice(view, "SomeUser", "no pm please")

      html = render(view)
      # Verify no PM-related elements for the sender appeared
      refute html =~ "pm:SomeUser"
    end
  end

  # ── US2: Send a Notice to a Channel ─────────────────────────

  describe "US2: sending /notice to a channel" do
    test "broadcasts channel notice when sender is a member", %{conn: conn} do
      ch = "#ntc_ch#{System.unique_integer([:positive])}"
      ensure_channel(ch)
      nick = "ChNtc#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Join the channel
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})
      Process.sleep(50)

      # Subscribe to the channel topic to verify broadcast
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{ch}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice #{ch} hello channel"})

      assert_receive %{event: "new_notice", payload: payload}, 1000
      assert payload.author == nick
      assert payload.content == "hello channel"
      assert payload.channel == ch
    end

    test "shows error when sender is not a member of the channel", %{conn: conn} do
      ch = "#ntc_nomem#{System.unique_integer([:positive])}"
      ensure_channel(ch)
      nick = "ChNtcE#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice #{ch} hello"})

      html = render(view)
      assert html =~ "must be a member"
    end
  end

  describe "US2: receiving a channel notice" do
    test "renders channel notice with -Nick- prefix in chat stream", %{conn: conn} do
      nick = "ChRcv#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_notice(view, "Alice", "maintenance soon", "#lobby")

      html = render(view)
      assert html =~ "-Alice-"
      assert html =~ "maintenance soon"
      assert html =~ "chat-notice"
    end

    test "channel notice from ignored user is silently dropped", %{conn: conn} do
      nick = "ChIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})

      send_channel_notice(view, "SpamBot", "hidden channel notice", "#lobby")

      html = render(view)
      refute html =~ "hidden channel notice"
    end

    test "channel notice does NOT trigger play_sound event", %{conn: conn} do
      nick = "ChSnd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
      # Consume connect sound event
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_channel_notice(view, "Alice", "quiet channel notice", "#lobby")

      refute_push_event(view, "play_sound", %{})
    end
  end

  # ── US3: Notice Routing Preferences ─────────────────────────

  describe "US3: /notice_routing show and set" do
    test "show current routing displays default :active", %{conn: conn} do
      nick = "RtShow#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice_routing"})

      html = render(view)
      assert html =~ "Notice routing is set to: active"
    end

    test "set routing to status shows confirmation", %{conn: conn} do
      nick = "RtSet#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice_routing status"})

      html = render(view)
      assert html =~ "Notice routing set to: status"
    end

    test "set routing to sender shows confirmation", %{conn: conn} do
      nick = "RtSdr#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice_routing sender"})

      html = render(view)
      assert html =~ "Notice routing set to: sender"
    end

    test "invalid routing value shows error", %{conn: conn} do
      nick = "RtInv#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice_routing invalid"})

      html = render(view)
      assert html =~ "Invalid routing"
    end
  end

  describe "US3: routing behavior for received notices" do
    test "notice with :active routing inserts into chat_messages", %{conn: conn} do
      nick = "RtAct#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Default routing is :active
      send_notice(view, "Alice", "active-routed notice")

      html = render(view)
      assert html =~ "active-routed notice"
      assert html =~ "-Alice-"
    end

    test "notice with :status routing and status tab open inserts into status_messages", %{
      conn: conn
    } do
      nick = "RtSts#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Set routing to status
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice_routing status"})

      # Open status tab
      render_click(view, "switch_to_status")

      send_notice(view, "Bob", "status-routed notice")

      html = render(view)
      assert html =~ "status-routed notice"
    end

    test "notice with :status routing and no status tab falls back to chat_messages", %{
      conn: conn
    } do
      nick = "RtStF#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Set routing to status (no status tab open)
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice_routing status"})

      send_notice(view, "Bob", "fallback notice")

      html = render(view)
      assert html =~ "fallback notice"
      assert html =~ "-Bob-"
    end
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp send_notice(view, sender, content) do
    send(
      view.pid,
      {:new_notice, %{sender: sender, content: content, timestamp: DateTime.utc_now()}}
    )

    Process.sleep(50)
  end

  defp send_channel_notice(view, author, content, channel) do
    send(view.pid, %{
      event: "new_notice",
      payload: %{
        author: author,
        content: content,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    })

    Process.sleep(50)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
