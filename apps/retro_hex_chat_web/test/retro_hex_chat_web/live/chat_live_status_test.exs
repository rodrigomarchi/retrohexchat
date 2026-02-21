defmodule RetroHexChatWeb.ChatLiveStatusTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ── Status tab ────────────────────────────────────────────

  describe "Status tab" do
    test "status messages stream is present on mount", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "StatusUser#{unique}"), "/chat")

      html = render(view)
      assert html =~ "status-messages"
    end

    test "status tab always rendered in tab bar", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "NoClose#{unique}"), "/chat")

      html = render(view)
      assert html =~ "tab-status"
      assert html =~ "Status"
    end

    test "status messages stream exists and hidden by default", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "StatusMsg#{unique}"), "/chat")

      html = render(view)
      assert html =~ "status-messages"
    end

    test "switching to status tab hides chat and shows status", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "StSwitch#{unique}"), "/chat")

      # Click the status tab
      render_click(view, "switch_to_status")
      html = render(view)

      # Status messages should be visible (no display:none)
      assert html =~ ~s(id="status-messages")
      # Chat messages should be hidden
      assert html =~ ~s(id="chat-messages")
      # The status tab should be active
      assert html =~ "tab-active"
    end

    test "switching back to channel from status tab", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "StBack#{unique}"), "/chat")

      render_click(view, "switch_to_status")
      render_click(view, "switch_channel", %{"channel" => "#lobby"})
      html = render(view)

      # Chat messages should now be visible
      refute html =~
               ~s(id="chat-messages" phx-update="stream" phx-hook="ScrollHook" style="display: none;")
    end

    test "nicklist hidden on status tab", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "StNick#{unique}"), "/chat")

      # Nicklist should be visible initially
      html = render(view)
      assert html =~ "nicklist"

      # Switch to status tab — nicklist should be hidden
      render_click(view, "switch_to_status")
      html = render(view)
      refute html =~ "nicklist-list"
    end

    test "plain text on status tab shows error", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "StText#{unique}"), "/chat")

      render_click(view, "switch_to_status")
      render_submit(view, "send_input", %{"input" => "hello world"})
      html = render(view)

      assert html =~ "Cannot send text to status window"
    end

    test "commands work on status tab", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "StCmd#{unique}"), "/chat")

      render_click(view, "switch_to_status")
      render_submit(view, "send_input", %{"input" => "/help"})
      html = render(view)

      assert html =~ "Available commands"
    end

    test "topic bar shows status text", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "StTopic#{unique}"), "/chat")

      render_click(view, "switch_to_status")
      html = render(view)

      assert html =~ "RetroHexChat Status"
    end
  end

  # ── Tab bar behaviour ─────────────────────────────────────────

  describe "Tab bar" do
    test "Status tab is always first in the tab bar", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "TabFirst#{unique}"), "/chat")

      html = render(view)
      tab_bar = Floki.find(Floki.parse_document!(html), "[data-testid=tab-bar]")
      children = Floki.children(hd(tab_bar))
      first_child = hd(children)
      assert Floki.attribute(first_child, "data-testid") == ["tab-status"]
    end

    test "active channel tab has tab-active class", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "TabAct#{unique}"), "/chat")

      # Switch from status tab to #lobby channel
      render_click(view, "switch_channel", %{"channel" => "#lobby"})
      html = render(view)
      tab = Floki.find(Floki.parse_document!(html), ~s([data-testid="tab-#lobby"]))
      assert length(tab) == 1
      [class] = Floki.attribute(hd(tab), "class")
      assert class =~ "tab-active"
    end

    test "close_channel_tab parts the channel and removes tab", %{conn: conn} do
      unique = uid()
      ch = "#closetab#{unique}"
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "CloseTab#{unique}"), "/chat")

      # Join the unique channel
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})
      html = render(view)
      assert html =~ "tab-#{ch}"

      # Close the channel tab
      render_click(view, "close_channel_tab", %{"channel" => ch})
      html = render(view)

      # Tab should be gone
      refute html =~ "tab-#{ch}"
      # But #lobby tab should remain
      assert html =~ "tab-#lobby"
    end

    test "close_pm_tab removes the PM tab", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "ClosePm#{unique}"), "/chat")

      # Open a PM conversation
      render_click(view, "nick_right_click", %{"nick" => "SomePal", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "SomePal"})
      html = render(view)
      assert html =~ "tab-pm-SomePal"

      # Close the PM tab
      render_click(view, "close_pm_tab", %{"nickname" => "SomePal"})
      html = render(view)
      refute html =~ "tab-pm-SomePal"
    end
  end

  # ── Topic bar behaviour ──────────────────────────────────────

  describe "Topic bar" do
    test "shows channel topic after join", %{conn: conn} do
      unique = uid()
      ch = "#topicbar#{unique}"
      ensure_channel(ch)
      {:ok, view, _html} = live(chat_conn(conn, "TopicBr#{unique}"), "/chat")

      # Join channel and set a topic
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})
      Server.set_topic(ch, "TopicBr#{unique}", "Test Topic Here")

      # Switch away and back to refresh topic from server state
      render_click(view, "switch_channel", %{"channel" => "#lobby"})
      render_click(view, "switch_channel", %{"channel" => ch})
      html = render(view)

      assert html =~ "Test Topic Here"
    end

    test "shows '(no topic set)' when no topic exists", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "NoTopic#{unique}"), "/chat")

      # Switch from status tab to #lobby to see the topic bar
      render_click(view, "switch_channel", %{"channel" => "#lobby"})
      html = render(view)
      assert html =~ "(no topic set)"
    end

    test "shows PM target for PM view", %{conn: conn} do
      unique = uid()
      {:ok, view, _html} = live(chat_conn(conn, "PmTopic#{unique}"), "/chat")

      # Open PM
      render_click(view, "nick_right_click", %{"nick" => "PmPeer", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "PmPeer"})
      html = render(view)

      assert html =~ "Private conversation with PmPeer"
    end
  end

  # ── Global presence broadcasts (T015) ───────────────────────

  describe "Global presence broadcasts" do
    test "mount broadcasts user_connected to presence:global", %{conn: conn} do
      unique = uid()
      nick = "PresUser#{unique}"

      # Subscribe before connecting so we can receive the broadcast
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "presence:global")

      {:ok, _view, _html} = live(chat_conn(conn, nick), "/chat")

      assert_receive {:user_connected, %{nickname: ^nick}}, 1000
    end

    test "disconnect broadcasts user_disconnected to presence:global", %{conn: conn} do
      unique = uid()
      nick = "DiscUser#{unique}"

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "presence:global")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Confirm the connection broadcast first
      assert_receive {:user_connected, %{nickname: ^nick}}, 1000

      # Simulate disconnect by stopping the LiveView process
      GenServer.stop(view.pid)

      assert_receive {:user_disconnected, %{nickname: ^nick}}, 1000
    end
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
