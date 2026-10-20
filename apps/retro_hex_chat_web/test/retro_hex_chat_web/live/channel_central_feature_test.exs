defmodule RetroHexChatWeb.ChannelCentralFeatureTest do
  @moduledoc """
  End-to-end tests for the Channel Central Dialog feature (007).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Chat.HelpTopics

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Read-Only Channel Central
  # ══════════════════════════════════════════════════════════════

  describe "US1: Open and View Channel Central" do
    # Opening, the desktop window it drives, and the programmatic close that
    # resets the island — one dialog's life on one mount.
    test "1.1 open shows the dialog, drives the desktop window, and closing resets it",
         %{conn: conn} do
      view = connect_user(conn, "E2ECc#{uid()}")
      html = open_cc(view, "#lobby")

      assert html =~ "Channel Central"
      assert html =~ "#lobby"

      assert_push_event(view, "window_command", %{action: "open", id: "channel-central"})
      assert has_element?(view, ~s([data-testid="channel-central-window"]))
      assert html =~ "Channel Central: #lobby"

      render_click(view, "close_channel_central")

      assert_push_event(view, "window_command", %{action: "close", id: "channel-central"})
      # The island resets to its closed state: no channel data left in the panel.
      refute has_element?(view, "#channel-central-dialog-content", "#lobby")
    end

    test "1.2b conversation toolbar opens Channel Central for the active channel", %{conn: conn} do
      view = connect_user(conn, "E2ECcTb#{uid()}")

      view
      |> element(~s([data-testid="conversation-toolbar-channel-central"]))
      |> render_click()

      assert_push_event(view, "window_command", %{action: "open", id: "channel-central"})
      assert has_element?(view, ~s([data-testid="channel-central-window"]))
      assert render(view) =~ "Channel Central: #lobby"
    end

    test "1.5 all 4 tabs are visible and switchable", %{conn: conn} do
      view = connect_user(conn, "E2ECcTb#{uid()}")
      open_cc(view, "#lobby")

      # Tab General is default
      html = render(view)
      assert html =~ "Members:"

      # Switch to Modes
      html = cc(view, "channel_central_tab", %{"tab" => "modes"})
      assert html =~ "Moderated (+m)"

      # Access Lists opens on Bans
      html = cc(view, "channel_central_tab", %{"tab" => "access_lists"})
      assert html =~ "No bans"

      # Switch to Ban Exceptions
      html = cc_list(view, "ban_exceptions")
      assert html =~ "No ban exceptions"

      # Switch to Invite Exceptions
      html = cc_list(view, "invite_exceptions")
      assert html =~ "No invite exceptions"

      # Registration is still its own tab
      html = cc(view, "channel_central_tab", %{"tab" => "registration"})
      assert html =~ "Not registered"
    end

    test "1.6 non-operator sees read-only view (no edit controls)", %{conn: conn} do
      channel = "#e2ero-#{uid()}"
      ensure_channel(channel)
      Server.join(channel, "E2EFounder")

      view = connect_user(conn, "E2ECcRo#{uid()}")
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      html = open_cc(view, channel)

      # No Save Topic button
      refute html =~ "Save Topic"

      # Modes tab — disabled checkboxes, no Apply Modes
      html = cc(view, "channel_central_tab", %{"tab" => "modes"})
      assert html =~ "disabled"
      refute html =~ "Apply Modes"

      # Access Lists / Bans — no Add/Remove buttons
      html = cc(view, "channel_central_tab", %{"tab" => "access_lists"})
      refute html =~ "cc_open_add_list_entry"
      assert html =~ "channel operator to manage"

      # Ban Exceptions — no buttons
      html = cc_list(view, "ban_exceptions")
      refute html =~ "cc_open_add_list_entry"
      assert html =~ "channel operator to manage"

      # Invite Exceptions — no buttons
      html = cc_list(view, "invite_exceptions")
      refute html =~ "cc_open_add_list_entry"
      assert html =~ "channel operator to manage"
    end

    test "1.7 operator sees editable controls", %{conn: conn} do
      channel = "#e2eop-#{uid()}"
      nick = "E2ECcOp#{uid()}"
      view = connect_user(conn, nick)
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      Server.ban(channel, nick, "OpBan")
      html = open_cc(view, channel)

      # Save Topic button visible
      assert html =~ "Save Topic"

      # Modes tab — Apply Modes button visible
      html = cc(view, "channel_central_tab", %{"tab" => "modes"})
      assert html =~ "Apply Modes"

      # Access Lists — Add belongs to the panel, Remove to the banned row.
      html = cc(view, "channel_central_tab", %{"tab" => "access_lists"})
      assert html =~ "cc_open_add_list_entry"
      assert html =~ ~s(data-testid="cc-list-remove-OpBan")
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US2 — Operator Topic Editing
  # ══════════════════════════════════════════════════════════════

  describe "US2: Topic Editing" do
    test "2.1 operator sets and then clears the topic from Channel Central", %{conn: conn} do
      channel = "#e2etp-#{uid()}"
      view = connect_user(conn, "E2ETpOp#{uid()}")
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      open_cc(view, channel)

      view
      |> element("form[phx-submit=cc_set_topic]")
      |> render_submit(%{"topic" => "E2E test topic"})

      html = render(view)
      assert html =~ "E2E test topic"

      # Verify server state
      {:ok, state} = Server.get_state(channel)
      assert state.topic == "E2E test topic"

      # Clearing a set topic stores the empty string.
      view |> element("form[phx-submit=cc_set_topic]") |> render_submit(%{"topic" => ""})

      {:ok, state} = Server.get_state(channel)
      assert state.topic == ""
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US3 — Operator Mode Toggles
  # ══════════════════════════════════════════════════════════════

  describe "US3: Mode Toggles" do
    # Each submit is checked against the server before the next one is sent.
    test "3.1 operator toggles +m, sets +k key and +l limit", %{conn: conn} do
      channel = "#e2emd-#{uid()}"
      view = connect_user(conn, "E2EMd#{uid()}")
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      open_cc(view, channel)

      cc(view, "channel_central_tab", %{"tab" => "modes"})

      view
      |> element("form[phx-submit=cc_apply_modes]")
      |> render_submit(%{"moderated" => "true"})

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "m"

      view
      |> element("form[phx-submit=cc_apply_modes]")
      |> render_submit(%{"has_key" => "true", "key_value" => "mykey"})

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "k"

      view
      |> element("form[phx-submit=cc_apply_modes]")
      |> render_submit(%{"has_limit" => "true", "limit_value" => "25"})

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "l"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US3b — Feature 09 Channel Configuration Gaps
  # ══════════════════════════════════════════════════════════════

  describe "US3b: Welcome, throttle, and ownership transfer" do
    test "operator saves and clears the welcome message and applies +j and -j from General tab",
         %{conn: conn} do
      channel = "#e2ewl-#{uid()}"
      nick = "E2EWl#{uid()}"
      view = connect_user(conn, nick)
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      html = open_cc(view, channel)

      assert html =~ "Welcome Message"
      assert html =~ "Save Welcome"
      assert html =~ "Clear Welcome"

      html =
        view
        |> element("form[phx-submit=cc_save_welcome]")
        |> render_submit(%{"message" => "Read the topic before chatting"})

      assert html =~ "Welcome message saved."
      assert html =~ "Read the topic before chatting"

      assert {:ok, %{message: "Read the topic before chatting", set_by: ^nick}} =
               Server.get_welcome(channel)

      html = cc(view, "cc_clear_welcome")

      assert html =~ "Welcome message cleared."
      assert html =~ "No welcome message set."
      assert {:ok, nil} = Server.get_welcome(channel)

      # The join throttle sits on the same tab: +j, then -j.
      html = render(view)
      assert html =~ "Join throttle"
      assert html =~ "Apply Throttle"

      html =
        view
        |> element("form[phx-submit=cc_apply_throttle]")
        |> render_submit(%{"seconds" => "30"})

      assert html =~ "Join throttle set to 30 seconds."
      {:ok, state} = Server.get_state(channel)
      assert state.modes_detail.join_throttle == {5, 30}

      html =
        view
        |> element("form[phx-submit=cc_apply_throttle]")
        |> render_submit(%{"seconds" => "0"})

      assert html =~ "Join throttle disabled."
      {:ok, state} = Server.get_state(channel)
      assert state.modes_detail.join_throttle == nil
    end

    test "non-operators see welcome and throttle read-only", %{conn: conn} do
      channel = "#e2ero-cfg-#{uid()}"
      owner = "CfgOwner#{uid()}"
      guest = "CfgGuest#{uid()}"

      # The owner only has to be in the channel first, not on a screen.
      ensure_channel(channel)
      {:ok, _state} = Server.join(channel, owner)
      :ok = Server.set_welcome(channel, "Owner managed welcome", owner)
      :ok = Server.set_mode(channel, owner, "+j", ["5:45"])

      view = connect_user(conn, guest)
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      html = open_cc(view, channel)

      assert html =~ "Welcome Message"
      assert html =~ "Owner managed welcome"
      assert html =~ "You must be a channel operator to edit the welcome message."
      assert html =~ "You must be a channel operator to change the join throttle."
      assert html =~ ~s(data-testid="cc-welcome-message-input")
      assert html =~ ~s(data-testid="cc-throttle-seconds-input")
      refute html =~ "Save Welcome"
      refute html =~ "Apply Throttle"
      refute html =~ "Transfer Ownership"
    end

    test "owner transfers ownership through confirm sub-form", %{conn: conn} do
      channel = "#e2etr-#{uid()}"
      owner = "E2EOwner#{uid()}"
      target = "E2ENew#{uid()}"

      owner_view = connect_user(conn, owner)
      submit_command_sync(owner_view, "/join #{channel}")
      {:ok, _state} = Server.join(channel, target)

      render_click(owner_view, "switch_channel", %{"channel" => channel})
      html = open_cc(owner_view, channel)

      assert html =~ "Transfer Ownership"

      html = cc(owner_view, "cc_open_transfer")
      assert html =~ "Transfer Ownership"
      assert html =~ "This cannot be undone"

      html =
        owner_view
        |> element("form[phx-submit=cc_transfer_ownership]")
        |> render_submit(%{"nickname" => ""})

      assert html =~ "Nickname is required."

      html =
        owner_view
        |> element("form[phx-submit=cc_transfer_ownership]")
        |> render_submit(%{"nickname" => target})

      assert html =~ "Channel ownership transferred"
      refute html =~ "cc-transfer-dialog"

      {:ok, state} = Server.get_state(channel)
      assert target in state.owners
      assert owner in state.operators
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US4 — Ban Management
  # ══════════════════════════════════════════════════════════════

  describe "US4: Ban Management" do
    # An entry already on the list when the dialog opens, and one added through
    # its dialog, both leave through their own row's Remove.
    test "4.1 operator adds a ban via dialog and removes bans", %{conn: conn} do
      channel = "##e2ebn-#{uid()}"
      nick = "E2EBn#{uid()}"
      view = connect_user(conn, nick)
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})

      Server.ban(channel, nick, "TempBan")
      open_cc(view, channel)

      cc(view, "channel_central_tab", %{"tab" => "access_lists"})
      assert render(view) =~ "TempBan"

      cc(view, "cc_open_add_list_entry")

      html = render(view)
      assert html =~ "cc-add-list-entry-dialog"
      assert html =~ ~s(data-access-list="bans")
      assert html =~ "Add Ban"

      view
      |> element("form[phx-submit=cc_add_list_entry]")
      |> render_submit(%{"nickname" => "Spammer"})

      html = render(view)
      assert html =~ "Spammer"

      cc(view, "cc_remove_list_entry", %{"nickname" => "TempBan"})
      cc(view, "cc_remove_list_entry", %{"nickname" => "Spammer"})

      html = render(view)
      # After removing both, the table shows the empty placeholder
      assert html =~ "No bans"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US5 — Ban Exceptions (+e)
  # ══════════════════════════════════════════════════════════════

  describe "US5: Ban Exceptions" do
    # An entry already on the list when the dialog opens, and one added through
    # its dialog, both leave through their own row's Remove.
    test "5.1 operator adds a ban exception via dialog and removes ban exceptions", %{conn: conn} do
      channel = "##e2ebe-#{uid()}"
      nick = "E2EBe#{uid()}"
      view = connect_user(conn, nick)
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})

      Server.add_ban_exception(channel, nick, "ExUser")
      open_cc(view, channel)

      cc(view, "channel_central_tab", %{"tab" => "access_lists"})
      cc_list(view, "ban_exceptions")
      assert render(view) =~ "ExUser"

      cc(view, "cc_open_add_list_entry")

      html = render(view)
      assert html =~ "cc-add-list-entry-dialog"
      assert html =~ ~s(data-access-list="ban_exceptions")
      assert html =~ "Add Ban Exception"

      view
      |> element("form[phx-submit=cc_add_list_entry]")
      |> render_submit(%{"nickname" => "Exempt1"})

      html = render(view)
      assert html =~ "Exempt1"

      cc(view, "cc_remove_list_entry", %{"nickname" => "ExUser"})
      cc(view, "cc_remove_list_entry", %{"nickname" => "Exempt1"})

      html = render(view)
      # After removing both, the table shows the empty placeholder
      assert html =~ "No ban exceptions"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US6 — Invite Exceptions (+I)
  # ══════════════════════════════════════════════════════════════

  describe "US6: Invite Exceptions" do
    # An entry already on the list when the dialog opens, and one added through
    # its dialog, both leave through their own row's Remove.
    test "6.1 operator adds an invite exception via dialog and removes invite exceptions", %{
      conn: conn
    } do
      channel = "##e2eie-#{uid()}"
      nick = "E2EIe#{uid()}"
      view = connect_user(conn, nick)
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})

      Server.add_invite_exception(channel, nick, "InvEx1")
      open_cc(view, channel)

      cc(view, "channel_central_tab", %{"tab" => "access_lists"})
      cc_list(view, "invite_exceptions")
      assert render(view) =~ "InvEx1"

      cc(view, "cc_open_add_list_entry")

      html = render(view)
      assert html =~ "cc-add-list-entry-dialog"
      assert html =~ ~s(data-access-list="invite_exceptions")
      assert html =~ "Add Invite Exception"

      view
      |> element("form[phx-submit=cc_add_list_entry]")
      |> render_submit(%{"nickname" => "InvUser"})

      html = render(view)
      assert html =~ "InvUser"

      cc(view, "cc_remove_list_entry", %{"nickname" => "InvEx1"})
      cc(view, "cc_remove_list_entry", %{"nickname" => "InvUser"})

      html = render(view)
      # After removing both, the table shows the empty placeholder
      assert html =~ "No invite exceptions"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US7 — Real-Time Updates
  # ══════════════════════════════════════════════════════════════

  describe "US7: Real-Time Updates" do
    # Topic, mode and ban changes made elsewhere all reach one open dialog.
    test "7.1 topic, mode and ban changes update the open dialog", %{conn: conn} do
      channel = "#e2ert1-#{uid()}"
      nick = "E2ERt1#{uid()}"
      view = connect_user(conn, nick)
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      open_cc(view, channel)

      Server.set_topic(channel, nick, "Real-time topic")
      html = render(view)
      assert html =~ "Real-time topic"

      Server.set_mode(channel, nick, "+m", [])

      # Flush PubSub + re-render to pick up the mode_changed broadcast
      render(view)
      render(view)
      cc(view, "channel_central_tab", %{"tab" => "modes"})
      html = render(view)
      assert html =~ "Moderated (+m)"

      Server.ban(channel, nick, "RtBanned")
      render(view)
      cc(view, "channel_central_tab", %{"tab" => "access_lists"})
      html = render(view)
      assert html =~ "RtBanned"
    end

    # Remove used to act on "whatever is selected", so switching list type had to
    # remember to clear the selection or the button pointed at a row that was no
    # longer on screen. A control that belongs to its own row cannot go stale:
    # it leaves with the row.
    test "7.4 a removed list type takes its controls with it", %{conn: conn} do
      channel = "#e2ert4-#{uid()}"
      nick = "E2ERt4#{uid()}"
      view = connect_user(conn, nick)
      submit_command_sync(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})

      Server.ban(channel, nick, "SelBan")
      open_cc(view, channel)

      cc(view, "channel_central_tab", %{"tab" => "access_lists"})
      assert has_element?(view, ~s([data-testid="cc-list-remove-SelBan"]))

      cc_list(view, "ban_exceptions")
      refute has_element?(view, ~s([data-testid="cc-list-remove-SelBan"]))
    end
  end

  describe "Feature 09 help documentation" do
    test "channel configuration topics include UI discovery and cross references" do
      welcome = HelpTopics.get_topic("channel-welcome-message")
      transfer = HelpTopics.get_topic("channel-transfer-ownership")
      mode_j = HelpTopics.get_topic("mode-j")
      permissions = HelpTopics.get_topic("channel-permissions")

      assert welcome != nil
      assert welcome.title == "Channel Welcome Message"
      assert "setwelcome" in welcome.keywords
      assert "channel central" in welcome.keywords

      assert transfer != nil
      assert transfer.title == "Transfer Channel Ownership"
      assert "transfer ownership" in transfer.keywords
      assert "channel central" in transfer.keywords

      assert "slow" in mode_j.keywords
      assert "channel central" in mode_j.keywords
      assert "transfer ownership" in permissions.keywords
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Helpers
  # ══════════════════════════════════════════════════════════════

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp cc(view, event, params \\ %{})

  defp cc(view, "channel_central_tab", %{"tab" => tab}) do
    view
    |> element("#channel-central-dialog-tabs .tabs-trigger[data-target='#{tab}']")
    |> render_click()
  end

  defp cc(view, event, params) do
    selector =
      "[phx-click='#{event}']" <>
        Enum.map_join(params, "", fn {k, v} -> "[phx-value-#{k}='#{v}']" end)

    view |> element(selector) |> render_click()
  end

  # Switches the Access Lists tab between bans / ban exceptions / invite
  # exceptions. The tab itself is reached with cc(view, "channel_central_tab", …).
  defp cc_list(view, list_type) do
    view
    |> element(~s([data-testid="cc-list-type-#{list_type}"]))
    |> render_click()
  end

  defp open_cc(view, channel) do
    render_click(view, "open_channel_central", %{"cc_channel" => channel})
    render(view)
  end
end
