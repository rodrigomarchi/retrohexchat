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
      sender = "NtcSnd#{uid()}"
      receiver = "NtcRcv#{uid()}"

      # Connect both users
      {:ok, _recv_view, _html} = live(chat_conn(conn, receiver), "/chat")
      {:ok, send_view, _html} = live(chat_conn(conn, sender), "/chat")

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
      nick = "NtcErr#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice OfflineUser hello"})

      html = render(view)
      assert html =~ "not found"
    end
  end

  describe "US1: receiving a notice" do
    test "renders notice with -Nick- prefix and .chat-notice class", %{conn: conn} do
      nick = "NtcRdr#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_notice(view, "Bob", "hey there")

      html = render(view)
      assert html =~ "-Bob-"
      assert html =~ "hey there"
      assert html =~ "chat-notice"
    end

    test "notice from ignored user is silently dropped", %{conn: conn} do
      nick = "NtcIgn#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Ignore the sender
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot"})

      send_notice(view, "SpamBot", "you should not see this notice")

      html = render(view)
      refute html =~ "you should not see this notice"
    end

    test "notice from user ignored with :notices type is dropped", %{conn: conn} do
      nick = "NtcIgnT#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Ignore only notices from sender
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot notices"})

      send_notice(view, "SpamBot", "hidden notice content")

      html = render(view)
      refute html =~ "hidden notice content"
    end

    test "notice does NOT trigger play_sound event", %{conn: conn} do
      nick = "NtcSnd2#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      # Consume connect sound event
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_notice(view, "Bob", "quiet notice")

      refute_push_event(view, "play_sound", %{})
    end

    test "notice does NOT create PM window or treebar entry", %{conn: conn} do
      nick = "NtcNoPm#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_notice(view, "SomeUser", "no pm please")

      html = render(view)
      # Verify no PM-related elements for the sender appeared
      refute html =~ "pm:SomeUser"
    end
  end

  # ── US2: Send a Notice to a Channel ─────────────────────────

  describe "US2: sending /notice to a channel" do
    test "broadcasts channel notice when sender is a member", %{conn: conn} do
      ch = "#ntc_ch#{uid()}"
      ensure_channel(ch)
      nick = "ChNtc#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

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
      ch = "#ntc_nomem#{uid()}"
      ensure_channel(ch)
      nick = "ChNtcE#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice #{ch} hello"})

      html = render(view)
      assert html =~ "must be a member"
    end
  end

  describe "US2: receiving a channel notice" do
    test "renders channel notice with -Nick- prefix in chat stream", %{conn: conn} do
      nick = "ChRcv#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_channel_notice(view, "Alice", "maintenance soon", "#lobby")

      html = render(view)
      assert html =~ "-Alice-"
      assert html =~ "maintenance soon"
      assert html =~ "chat-notice"
    end

    test "channel notice from ignored user is silently dropped", %{conn: conn} do
      nick = "ChIgn#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})

      send_channel_notice(view, "SpamBot", "hidden channel notice", "#lobby")

      html = render(view)
      refute html =~ "hidden channel notice"
    end

    test "channel notice does NOT trigger play_sound event", %{conn: conn} do
      nick = "ChSnd#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      # Consume connect sound event
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_channel_notice(view, "Alice", "quiet channel notice", "#lobby")

      refute_push_event(view, "play_sound", %{})
    end
  end

  # ── US3: Notice Routing Preferences ─────────────────────────

  describe "US3: /notice_routing command" do
    test "shows hardcoded routing message", %{conn: conn} do
      nick = "RtShow#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notice_routing"})

      html = render(view)
      assert html =~ "hardcoded to: active"
    end
  end

  describe "US3: notice routing behavior" do
    test "notices are always routed to active window", %{conn: conn} do
      nick = "RtAct#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_notice(view, "Alice", "active-routed notice")

      html = render(view)
      assert html =~ "active-routed notice"
      assert html =~ "-Alice-"
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
