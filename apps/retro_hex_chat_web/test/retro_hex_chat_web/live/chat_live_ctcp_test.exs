defmodule RetroHexChatWeb.ChatLiveCtcpTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ── US1: CTCP PING ─────────────────────────────────────────

  describe "US1: sending /ctcp <target> ping" do
    test "broadcasts {:ctcp_request, payload} to user topic", %{conn: conn} do
      sender = "CtSnd#{uid()}"
      receiver = "CtRcv#{uid()}"

      {:ok, _recv_view, _html} = live(chat_conn(conn, receiver), "/chat")
      {:ok, send_view, _html} = live(chat_conn(conn, sender), "/chat")

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{receiver}")

      send_view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp #{receiver} ping"})

      assert_receive {:ctcp_request, payload}, 1000
      assert payload.type == :ping
      assert payload.sender == sender
      assert is_binary(payload.request_id)
      assert is_integer(payload.sent_at)
    end

    test "shows error when target user is not online", %{conn: conn} do
      nick = "CtErr#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp OfflineUser ping"})

      html = render(view)
      assert html =~ "User &#39;OfflineUser&#39; not found" or html =~ "not found"
    end

    test "self-CTCP ping returns 0ms immediately", %{conn: conn} do
      nick = "CtSelf#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp #{nick} ping"})

      html = render(view)
      assert html =~ "CTCP PING reply from #{nick}: 0ms"
    end
  end

  describe "US1: receiving a CTCP PING request" do
    test "auto-replies and shows request system message", %{conn: conn} do
      nick = "CtReq#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Subscribe to the SENDER's topic to catch the auto-reply
      # (the reply is broadcast to user:#{sender}, i.e., user:Bob)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:Bob")

      send_ctcp_request(view, "Bob", :ping)

      html = render(view)
      assert html =~ "CTCP PING request from Bob"

      # Should have auto-replied to Bob's topic
      assert_receive {:ctcp_reply, reply_payload}, 1000
      assert reply_payload.type == :ping
      assert reply_payload.replier == nick
    end

    test "does not auto-reply when CTCP is disabled", %{conn: conn} do
      nick = "CtDis#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Disable CTCP via direct session manipulation
      disable_ctcp(view)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:Bob")

      send_ctcp_request(view, "Bob", :ping)

      refute_receive {:ctcp_reply, _}, 200
    end
  end

  describe "US1: receiving a CTCP PING reply" do
    test "shows latency message", %{conn: conn} do
      nick = "CtRpl#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      request_id = "req_#{uid()}"
      sent_at = System.monotonic_time(:millisecond)

      # Add a pending request
      add_pending_request(view, request_id, "Alice", :ping, sent_at)

      # Send the reply
      send_ctcp_reply(view, "Alice", :ping, request_id, "", sent_at)

      html = render(view)
      assert html =~ "CTCP PING reply from Alice:"
      assert html =~ "ms"
    end
  end

  describe "US1: CTCP timeout" do
    test "shows timeout message after timer fires", %{conn: conn} do
      nick = "CtTmo#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      request_id = "req_timeout_#{uid()}"

      # Add pending request and simulate timeout
      add_pending_request(view, request_id, "Alice", :ping, System.monotonic_time(:millisecond))

      # Fire the timeout
      send(view.pid, {:ctcp_timeout, request_id})
      Process.sleep(50)

      html = render(view)
      assert html =~ "No CTCP reply from Alice (timed out)"
    end
  end

  describe "US1: rate limiting" do
    test "blocks 4th request within 30 seconds to same target", %{conn: conn} do
      sender = "CtRate#{uid()}"
      receiver = "CtRcvR#{uid()}"

      {:ok, _recv_view, _html} = live(chat_conn(conn, receiver), "/chat")
      {:ok, view, _html} = live(chat_conn(conn, sender), "/chat")

      # Send 3 requests (should succeed)
      for _ <- 1..3 do
        view
        |> element("form.chat-input-form")
        |> render_submit(%{"input" => "/ctcp #{receiver} ping"})

        Process.sleep(20)
      end

      # 4th request should be rate limited
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp #{receiver} ping"})

      html = render(view)
      assert html =~ "rate limit"
    end
  end

  describe "US1: no PM windows or notifications" do
    test "CTCP request does NOT create PM window", %{conn: conn} do
      nick = "CtNoPm#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_ctcp_request(view, "SomeUser", :ping)

      html = render(view)
      refute html =~ "pm:SomeUser"
    end

    test "CTCP reply does NOT trigger play_sound event", %{conn: conn} do
      nick = "CtNoSnd#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      # Consume connect sound event
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      send_ctcp_request(view, "Alice", :ping)

      refute_push_event(view, "play_sound", %{})
    end
  end

  describe "US1: usage errors" do
    test "shows usage when no args given", %{conn: conn} do
      nick = "CtUsg1#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp"})

      html = render(view)
      assert html =~ "/ctcp"
      assert html =~ "&lt;target&gt;" or html =~ "target"
    end

    test "shows usage when only target given", %{conn: conn} do
      nick = "CtUsg2#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp Alice"})

      html = render(view)
      assert html =~ "/ctcp"
      assert html =~ "type" or html =~ "Valid types"
    end

    test "shows error for invalid CTCP type", %{conn: conn} do
      nick = "CtInv#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp Alice unknown"})

      html = render(view)
      assert html =~ "Unknown CTCP type: unknown"
      assert html =~ "ping"
      assert html =~ "version"
      assert html =~ "time"
      assert html =~ "finger"
    end
  end

  # ── US2: VERSION, TIME, FINGER ──────────────────────────────

  describe "US2: CTCP VERSION" do
    test "self-CTCP version returns client version string", %{conn: conn} do
      nick = "CtVer#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp #{nick} version"})

      html = render(view)
      assert html =~ "CTCP VERSION reply from #{nick}: RetroHexChat v1.0"
    end

    test "auto-replies with version string on request", %{conn: conn} do
      nick = "CtVRq#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:Bob")

      send_ctcp_request(view, "Bob", :version)

      html = render(view)
      assert html =~ "CTCP VERSION request from Bob"

      assert_receive {:ctcp_reply, reply}, 1000
      assert reply.type == :version
      assert reply.value == "RetroHexChat v1.0"
    end
  end

  describe "US2: CTCP TIME" do
    test "self-CTCP time returns server UTC time", %{conn: conn} do
      nick = "CtTim#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp #{nick} time"})

      html = render(view)
      assert html =~ "CTCP TIME reply from #{nick}:"
      assert html =~ "UTC"
    end

    test "auto-replies with UTC time on request", %{conn: conn} do
      nick = "CtTRq#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:Bob")

      send_ctcp_request(view, "Bob", :time)

      assert_receive {:ctcp_reply, reply}, 1000
      assert reply.type == :time
      assert reply.value =~ "UTC"
    end
  end

  describe "US2: CTCP FINGER" do
    test "self-CTCP finger returns idle time by default", %{conn: conn} do
      nick = "CtFng#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp #{nick} finger"})

      html = render(view)
      assert html =~ "CTCP FINGER reply from #{nick}:"
      assert html =~ nick
    end

    test "auto-replies with finger text on request", %{conn: conn} do
      nick = "CtFRq#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:Bob")

      send_ctcp_request(view, "Bob", :finger)

      assert_receive {:ctcp_reply, reply}, 1000
      assert reply.type == :finger
      assert reply.value =~ nick
    end
  end

  describe "US2: CTCP reply display" do
    test "VERSION reply is displayed as system message", %{conn: conn} do
      nick = "CtVDis#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      request_id = "req_v_#{uid()}"
      sent_at = System.monotonic_time(:millisecond)

      add_pending_request(view, request_id, "Alice", :version, sent_at)
      send_ctcp_reply(view, "Alice", :version, request_id, "MyCoolClient v3.0", sent_at)

      html = render(view)
      assert html =~ "CTCP VERSION reply from Alice: MyCoolClient v3.0"
    end

    test "TIME reply is displayed as system message", %{conn: conn} do
      nick = "CtTDis#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      request_id = "req_t_#{uid()}"
      sent_at = System.monotonic_time(:millisecond)

      add_pending_request(view, request_id, "Alice", :time, sent_at)
      send_ctcp_reply(view, "Alice", :time, request_id, "2026-02-12 10:30:00 UTC", sent_at)

      html = render(view)
      assert html =~ "CTCP TIME reply from Alice: 2026-02-12 10:30:00 UTC"
    end

    test "FINGER reply is displayed as system message", %{conn: conn} do
      nick = "CtFDis#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      request_id = "req_f_#{uid()}"
      sent_at = System.monotonic_time(:millisecond)

      add_pending_request(view, request_id, "Alice", :finger, sent_at)

      send_ctcp_reply(
        view,
        "Alice",
        :finger,
        request_id,
        "Alice - Elixir dev",
        sent_at
      )

      html = render(view)
      assert html =~ "CTCP FINGER reply from Alice: Alice - Elixir dev"
    end
  end

  # ── US3: CTCP Settings Dialog ───────────────────────────────

  describe "US3: CTCP settings dialog" do
    test "opens from Tools menu", %{conn: conn} do
      nick = "CtDlg#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_ctcp_settings_dialog")

      html = render(view)
      assert html =~ "CTCP Settings"
    end

    test "closes dialog", %{conn: conn} do
      nick = "CtDlgC#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_ctcp_settings_dialog")
      render_click(view, "close_ctcp_settings_dialog")

      html = render(view)
      refute html =~ "Enable CTCP responses"
    end

    test "saves settings and reflects in CTCP replies", %{conn: conn} do
      nick = "CtDlgS#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_ctcp_settings_dialog")

      render_click(view, "ctcp_save_settings", %{
        "enabled" => "true",
        "version_string" => "MyCoolClient v3.0",
        "finger_text" => "Custom finger text"
      })

      # Verify settings applied by doing self-CTCP
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ctcp #{nick} version"})

      html = render(view)
      assert html =~ "MyCoolClient v3.0"
    end
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp send_ctcp_request(view, sender, type) do
    send(
      view.pid,
      {:ctcp_request,
       %{
         type: type,
         sender: sender,
         request_id: "req_#{uid()}",
         sent_at: System.monotonic_time(:millisecond)
       }}
    )

    Process.sleep(50)
  end

  defp send_ctcp_reply(view, replier, type, request_id, value, sent_at) do
    send(
      view.pid,
      {:ctcp_reply,
       %{
         type: type,
         replier: replier,
         request_id: request_id,
         value: value,
         sent_at: sent_at
       }}
    )

    Process.sleep(50)
  end

  defp add_pending_request(view, request_id, target, type, sent_at) do
    send(
      view.pid,
      {:_test_add_ctcp_pending, request_id,
       %{
         target: target,
         type: type,
         sent_at: sent_at,
         timer_ref: make_ref()
       }}
    )

    Process.sleep(50)
  end

  defp disable_ctcp(view) do
    send(view.pid, {:_test_set_ctcp_enabled, false})
    Process.sleep(50)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
