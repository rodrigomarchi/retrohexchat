defmodule RetroHexChatWeb.ChannelCentralE2ETest do
  @moduledoc """
  End-to-end tests for the Channel Central Dialog feature (007).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Read-Only Channel Central
  # ══════════════════════════════════════════════════════════════

  describe "US1: Open and View Channel Central" do
    test "1.1 open via menu bar shows dialog", %{conn: conn} do
      view = connect_user(conn, "E2ECc#{uid()}")
      html = render_click(view, "open_channel_central", %{"cc_channel" => "#lobby"})

      assert html =~ "channel-central-dialog"
      assert html =~ "Channel Central"
      assert html =~ "#lobby"
    end

    test "1.2 close via X button hides dialog", %{conn: conn} do
      view = connect_user(conn, "E2ECcCl#{uid()}")
      render_click(view, "open_channel_central", %{"cc_channel" => "#lobby"})
      html = render_click(view, "close_channel_central")

      refute html =~ "channel-central-dialog"
    end

    test "1.3 close via Escape key hides dialog", %{conn: conn} do
      view = connect_user(conn, "E2ECcEs#{uid()}")
      render_click(view, "open_channel_central", %{"cc_channel" => "#lobby"})
      html = render_keydown(view, "window_keydown", %{"key" => "Escape"})

      refute html =~ "channel-central-dialog"
    end

    test "1.4 General tab shows channel info", %{conn: conn} do
      view = connect_user(conn, "E2ECcGn#{uid()}")
      html = render_click(view, "open_channel_central", %{"cc_channel" => "#lobby"})

      assert html =~ "cc-general-panel"
      assert html =~ "#lobby"
      assert html =~ "Members:"
    end

    test "1.5 all 5 tabs are visible and switchable", %{conn: conn} do
      view = connect_user(conn, "E2ECcTb#{uid()}")
      render_click(view, "open_channel_central", %{"cc_channel" => "#lobby"})

      # Tab General is default
      html = render(view)
      assert html =~ "cc-general-panel"

      # Switch to Modes
      html = view |> element("[data-testid=cc-tab-modes]") |> render_click()
      assert html =~ "cc-modes-panel"

      # Switch to Bans
      html = view |> element("[data-testid=cc-tab-bans]") |> render_click()
      assert html =~ "cc-bans-panel"

      # Switch to Ban Exceptions
      html = view |> element("[data-testid=cc-tab-ban-ex]") |> render_click()
      assert html =~ "cc-ban-ex-panel"

      # Switch to Invite Exceptions
      html = view |> element("[data-testid=cc-tab-invite-ex]") |> render_click()
      assert html =~ "cc-invite-ex-panel"
    end

    test "1.6 non-operator sees read-only view (no edit controls)", %{conn: conn} do
      channel = "#e2ero-#{uid()}"
      ensure_channel(channel)
      Server.join(channel, "E2EFounder")

      view = connect_user(conn, "E2ECcRo#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      html = render_click(view, "open_channel_central", %{"cc_channel" => channel})

      # No Set Topic button
      refute html =~ "cc-set-topic-btn"

      # Modes tab — disabled checkboxes, no Apply
      html = view |> element("[data-testid=cc-tab-modes]") |> render_click()
      assert html =~ "disabled"
      refute html =~ "cc-apply-modes-btn"

      # Bans tab — no Add/Remove buttons
      html = view |> element("[data-testid=cc-tab-bans]") |> render_click()
      refute html =~ "cc-add-ban-btn"
      refute html =~ "cc-remove-ban-btn"

      # Ban Exceptions tab — no buttons
      html = view |> element("[data-testid=cc-tab-ban-ex]") |> render_click()
      refute html =~ "cc-add-ban-ex-btn"

      # Invite Exceptions tab — no buttons
      html = view |> element("[data-testid=cc-tab-invite-ex]") |> render_click()
      refute html =~ "cc-add-invite-ex-btn"
    end

    test "1.7 operator sees editable controls", %{conn: conn} do
      channel = "#e2eop-#{uid()}"
      view = connect_user(conn, "E2ECcOp#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      html = render_click(view, "open_channel_central", %{"cc_channel" => channel})

      # Set Topic button visible
      assert html =~ "cc-set-topic-btn"
      assert html =~ "cc-topic-input"

      # Modes tab — Apply button visible
      html = view |> element("[data-testid=cc-tab-modes]") |> render_click()
      assert html =~ "cc-apply-modes-btn"

      # Bans tab — Add/Remove buttons visible
      html = view |> element("[data-testid=cc-tab-bans]") |> render_click()
      assert html =~ "cc-add-ban-btn"
      assert html =~ "cc-remove-ban-btn"
    end

    test "1.8 empty bans shows placeholder", %{conn: conn} do
      channel = "#e2eeb-#{uid()}"
      view = connect_user(conn, "E2ECcEb#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      html = view |> element("[data-testid=cc-tab-bans]") |> render_click()
      assert html =~ "No bans"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US2 — Operator Topic Editing
  # ══════════════════════════════════════════════════════════════

  describe "US2: Topic Editing" do
    test "2.1 operator sets topic from Channel Central", %{conn: conn} do
      channel = "#e2etp-#{uid()}"
      view = connect_user(conn, "E2ETpOp#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view
      |> element("form[phx-submit=cc_set_topic]")
      |> render_submit(%{"topic" => "E2E test topic"})

      html = render(view)
      assert html =~ "E2E test topic"

      # Verify server state
      {:ok, state} = Server.get_state(channel)
      assert state.topic == "E2E test topic"
    end

    test "2.2 clearing topic sets empty string", %{conn: conn} do
      channel = "#e2eclr-#{uid()}"
      nick = "E2EClr#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})

      Server.set_topic(channel, nick, "Temp topic")
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("form[phx-submit=cc_set_topic]") |> render_submit(%{"topic" => ""})

      {:ok, state} = Server.get_state(channel)
      assert state.topic == ""
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US3 — Operator Mode Toggles
  # ══════════════════════════════════════════════════════════════

  describe "US3: Mode Toggles" do
    test "3.1 operator toggles +m moderated", %{conn: conn} do
      channel = "#e2emd-#{uid()}"
      view = connect_user(conn, "E2EMd#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-modes]") |> render_click()

      view
      |> element("form[phx-submit=cc_apply_modes]")
      |> render_submit(%{"moderated" => "true"})

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "m"
    end

    test "3.2 operator sets +k key", %{conn: conn} do
      channel = "#e2eky-#{uid()}"
      view = connect_user(conn, "E2EKy#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-modes]") |> render_click()

      view
      |> element("form[phx-submit=cc_apply_modes]")
      |> render_submit(%{"has_key" => "true", "key_value" => "mykey"})

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "k"
    end

    test "3.3 operator sets +l limit", %{conn: conn} do
      channel = "#e2elm-#{uid()}"
      view = connect_user(conn, "E2ELm#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-modes]") |> render_click()

      view
      |> element("form[phx-submit=cc_apply_modes]")
      |> render_submit(%{"has_limit" => "true", "limit_value" => "25"})

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "l"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US4 — Ban Management
  # ══════════════════════════════════════════════════════════════

  describe "US4: Ban Management" do
    test "4.1 operator adds ban via dialog", %{conn: conn} do
      channel = "#e2ebn-#{uid()}"
      view = connect_user(conn, "E2EBn#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-bans]") |> render_click()
      view |> element("[data-testid=cc-add-ban-btn]") |> render_click()

      html = render(view)
      assert html =~ "cc-add-ban-dialog"

      view |> element("form[phx-submit=cc_add_ban]") |> render_submit(%{"nickname" => "Spammer"})

      html = render(view)
      assert html =~ "cc-ban-entry-Spammer"
    end

    test "4.2 operator removes ban", %{conn: conn} do
      channel = "#e2erb-#{uid()}"
      nick = "E2ERb#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})

      Server.ban(channel, nick, "TempBan")
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-bans]") |> render_click()

      html = render(view)
      assert html =~ "cc-ban-entry-TempBan"

      render_click(view, "cc_ban_select", %{"nickname" => "TempBan"})
      view |> element("[data-testid=cc-remove-ban-btn]") |> render_click()

      html = render(view)
      refute html =~ "cc-ban-entry-TempBan"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US5 — Ban Exceptions (+e)
  # ══════════════════════════════════════════════════════════════

  describe "US5: Ban Exceptions" do
    test "5.1 operator adds ban exception via dialog", %{conn: conn} do
      channel = "#e2ebe-#{uid()}"
      view = connect_user(conn, "E2EBe#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-ban-ex]") |> render_click()
      view |> element("[data-testid=cc-add-ban-ex-btn]") |> render_click()

      html = render(view)
      assert html =~ "cc-add-ban-ex-dialog"

      view
      |> element("form[phx-submit=cc_add_ban_exception]")
      |> render_submit(%{"nickname" => "Exempt1"})

      html = render(view)
      assert html =~ "cc-ban-ex-entry-Exempt1"
    end

    test "5.2 operator removes ban exception", %{conn: conn} do
      channel = "#e2erbx-#{uid()}"
      nick = "E2ERbx#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})

      Server.add_ban_exception(channel, nick, "ExUser")
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-ban-ex]") |> render_click()
      html = render(view)
      assert html =~ "cc-ban-ex-entry-ExUser"

      render_click(view, "cc_ban_ex_select", %{"nickname" => "ExUser"})
      view |> element("[data-testid=cc-remove-ban-ex-btn]") |> render_click()

      html = render(view)
      refute html =~ "cc-ban-ex-entry-ExUser"
    end

    test "5.3 empty ban exceptions shows placeholder", %{conn: conn} do
      channel = "#e2eebx-#{uid()}"
      view = connect_user(conn, "E2EEbx#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      html = view |> element("[data-testid=cc-tab-ban-ex]") |> render_click()
      assert html =~ "No ban exceptions"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US6 — Invite Exceptions (+I)
  # ══════════════════════════════════════════════════════════════

  describe "US6: Invite Exceptions" do
    test "6.1 operator adds invite exception via dialog", %{conn: conn} do
      channel = "#e2eie-#{uid()}"
      view = connect_user(conn, "E2EIe#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-invite-ex]") |> render_click()
      view |> element("[data-testid=cc-add-invite-ex-btn]") |> render_click()

      html = render(view)
      assert html =~ "cc-add-invite-ex-dialog"

      view
      |> element("form[phx-submit=cc_add_invite_exception]")
      |> render_submit(%{"nickname" => "InvUser"})

      html = render(view)
      assert html =~ "cc-invite-ex-entry-InvUser"
    end

    test "6.2 operator removes invite exception", %{conn: conn} do
      channel = "#e2erix-#{uid()}"
      nick = "E2ERix#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})

      Server.add_invite_exception(channel, nick, "InvEx1")
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      view |> element("[data-testid=cc-tab-invite-ex]") |> render_click()
      html = render(view)
      assert html =~ "cc-invite-ex-entry-InvEx1"

      render_click(view, "cc_invite_ex_select", %{"nickname" => "InvEx1"})
      view |> element("[data-testid=cc-remove-invite-ex-btn]") |> render_click()

      html = render(view)
      refute html =~ "cc-invite-ex-entry-InvEx1"
    end

    test "6.3 empty invite exceptions shows placeholder", %{conn: conn} do
      channel = "#e2eeix-#{uid()}"
      view = connect_user(conn, "E2EEix#{uid()}")
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      html = view |> element("[data-testid=cc-tab-invite-ex]") |> render_click()
      assert html =~ "No invite exceptions"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US7 — Real-Time Updates
  # ══════════════════════════════════════════════════════════════

  describe "US7: Real-Time Updates" do
    test "7.1 topic change updates open dialog", %{conn: conn} do
      channel = "#e2ert1-#{uid()}"
      nick = "E2ERt1#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      Server.set_topic(channel, nick, "Real-time topic")
      html = render(view)
      assert html =~ "Real-time topic"
    end

    test "7.2 mode change updates modes tab", %{conn: conn} do
      channel = "#e2ert2-#{uid()}"
      nick = "E2ERt2#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      Server.set_mode(channel, nick, "+m", [])

      # Flush PubSub + re-render to pick up the mode_changed broadcast
      render(view)
      render(view)
      html = view |> element("[data-testid=cc-tab-modes]") |> render_click()
      assert html =~ "Moderated (+m)"
    end

    test "7.3 ban added updates bans tab", %{conn: conn} do
      channel = "#e2ert3-#{uid()}"
      nick = "E2ERt3#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      Server.ban(channel, nick, "RtBanned")
      render(view)
      html = view |> element("[data-testid=cc-tab-bans]") |> render_click()
      assert html =~ "cc-ban-entry-RtBanned"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Helpers
  # ══════════════════════════════════════════════════════════════

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp submit_command(view, command) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => command})
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
