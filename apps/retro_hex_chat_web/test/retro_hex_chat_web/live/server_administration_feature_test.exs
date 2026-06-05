defmodule RetroHexChatWeb.ServerAdministrationFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChat.Services.Queries
  alias RetroHexChatWeb.Components.UI.{AdminConsoleDialog, MenuBarApp}

  setup do
    Application.put_env(:retro_hex_chat, :motd_cache, :unset)

    on_exit(fn ->
      Application.put_env(:retro_hex_chat, :motd_cache, :unset)
    end)

    :ok
  end

  describe "MOTD help entry point" do
    test "Help menu exposes Message of the Day for every connected user" do
      document =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          is_admin: false,
          on_action: "toolbar_action"
        )
        |> Floki.parse_document!()

      help_section =
        document
        |> Floki.find("nav > div")
        |> Enum.at(4)

      assert "show_motd" in menu_actions(help_section)
      assert Floki.raw_html(help_section) =~ "Message of the Day"
    end

    test "toolbar action show_motd renders the current MOTD in Status", %{conn: conn} do
      view = connect_user(conn, "MotdView#{uid()}")
      motd = "motd-menu-marker-#{uid()}"

      Application.put_env(:retro_hex_chat, :motd_cache, motd)

      html = render_click(view, "toolbar_action", %{"action" => "show_motd"})

      assert html =~ motd
      assert html =~ ~s(id="status-messages")
    end
  end

  describe "Feature 12 MOTD help documentation" do
    test "help topics describe the MOTD menu entry and cross-reference commands" do
      motd_ui = HelpTopics.get_topic("ui-message-of-the-day")
      cmd_motd = HelpTopics.get_topic("cmd-motd")
      special_messages = HelpTopics.get_topic("feature-special-messages")
      admin_console = HelpTopics.get_topic("feature-admin-console")

      assert motd_ui != nil
      assert "show_motd" in motd_ui.keywords
      assert "Help menu" in motd_ui.keywords
      assert "ui-message-of-the-day" in cmd_motd.see_also
      assert "ui-message-of-the-day" in special_messages.see_also
      assert "server settings" in admin_console.keywords
      assert "server settings tab" in admin_console.keywords
      assert "motd tab" in admin_console.keywords
      assert "turn tab" in admin_console.keywords
      assert "audit log tab" in admin_console.keywords
      assert "danger zone" in admin_console.keywords
      assert "cmd-setmotd" in admin_console.see_also
      assert "cmd-clearmotd" in admin_console.see_also
      assert "cmd-admin-nuke" in admin_console.see_also

      broadcasts = HelpTopics.get_topic("feature-server-broadcasts")

      assert broadcasts != nil
      assert "wallops" in broadcasts.keywords
      assert "announce" in broadcasts.keywords
      assert "cmd-wallops" in broadcasts.see_also
      assert "cmd-announce" in broadcasts.see_also
      assert "feature-server-broadcasts" in admin_console.see_also
    end
  end

  describe "Admin Console tabbed shell" do
    test "component renders all structured tabs and preserves the raw Console runner" do
      document =
        render_component(&AdminConsoleDialog.admin_console_dialog/1,
          id: "admin-console-dialog",
          show: true,
          active_tab: "console",
          results: [],
          on_tab: "admin_console_tab",
          on_close: "close_admin_console"
        )
        |> Floki.parse_document!()

      assert tab_labels(document) == [
               "Server Settings",
               "Users",
               "Channels",
               "MOTD",
               "Broadcast",
               "Audit Log",
               "TURN",
               "Danger Zone",
               "Console"
             ]

      html = Floki.raw_html(document)
      assert html =~ ~s(value="console")
      assert html =~ ~s(phx-submit="execute_admin_console")
      assert html =~ ~s(id="admin-console-input")
    end

    test "toolbar action opens the tabbed Admin Console for an identified admin", %{conn: conn} do
      view = connect_admin(conn)

      html = render_click(view, "toolbar_action", %{"action" => "open_admin_console"})

      assert html =~ "Server Settings"
      assert html =~ "Danger Zone"
      assert html =~ "Console"
      assert html =~ ~s(id="admin-console-input")
    end
  end

  describe "Admin Console Server Settings tab" do
    test "component renders editable settings, info/settings output, and command controls" do
      document =
        render_component(&AdminConsoleDialog.admin_console_dialog/1,
          id: "admin-console-dialog",
          show: true,
          active_tab: "server_settings",
          results: [],
          server_settings_info: "*** RetroHexChat ***",
          server_settings_text: "*** Server Settings ***",
          server_settings_values: %{
            "server_name" => "RetroHexChat",
            "server_description" => "A test server",
            "welcome_message" => "Welcome",
            "max_channels" => "10",
            "registration" => "open",
            "whowas_retention_seconds" => "3600"
          },
          server_settings_result: nil,
          server_settings_can_edit: true,
          on_tab: "admin_console_tab",
          on_server_settings_save: "admin_console_save_server_settings",
          on_server_settings_refresh: "admin_console_refresh_server_settings",
          on_singleplayer: "admin_console_start_singleplayer",
          on_close: "close_admin_console"
        )
        |> Floki.parse_document!()

      html = Floki.raw_html(document)

      assert html =~ ~s(data-testid="admin-console-tab-server-settings")
      assert html =~ ~s(id="admin-console-server-settings-form")
      assert html =~ ~s(phx-submit="admin_console_save_server_settings")
      assert html =~ ~s(name="server_name")
      assert html =~ ~s(name="server_description")
      assert html =~ ~s(name="welcome_message")
      assert html =~ ~s(name="max_channels")
      assert html =~ ~s(name="registration")
      assert html =~ ~s(name="whowas_retention_seconds")
      assert html =~ ~s(id="admin-console-server-info")
      assert html =~ "*** RetroHexChat ***"
      assert html =~ ~s(id="admin-console-server-settings-output")
      assert html =~ "*** Server Settings ***"
      assert html =~ "Save settings"
      assert html =~ "Start solo arcade"
      assert html =~ "Refresh"
    end

    test "admin can save server settings through the structured tab", %{conn: conn} do
      original_description = Queries.get_setting("server_description")
      initial_description = "server-settings-initial-#{uid()}"
      new_description = "server-settings-updated-#{uid()}"

      Queries.upsert_setting("server_description", initial_description, "TestSeed")

      on_exit(fn ->
        if original_description do
          Queries.upsert_setting("server_description", original_description, "TestSeed")
        else
          Queries.delete_setting("server_description")
        end
      end)

      view = connect_admin(conn)

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      html = render_click(view, "admin_console_tab", %{"tab" => "server_settings"})

      assert html =~ initial_description

      html =
        view
        |> form("#admin-console-server-settings-form", %{
          "server_description" => new_description
        })
        |> render_submit()

      assert html =~ "Server setting &#39;server_description&#39; set to"
      assert html =~ new_description
      assert Queries.get_setting("server_description") == new_description
    end
  end

  describe "Admin Console MOTD tab" do
    test "component renders current MOTD, editor, and command-backed controls" do
      document =
        render_component(&AdminConsoleDialog.admin_console_dialog/1,
          id: "admin-console-dialog",
          show: true,
          active_tab: "motd",
          results: [],
          motd_content: "Current admin console MOTD",
          motd_result: nil,
          on_tab: "admin_console_tab",
          on_motd_set: "admin_console_set_motd",
          on_motd_clear: "admin_console_clear_motd",
          on_motd_refresh: "admin_console_refresh_motd",
          on_close: "close_admin_console"
        )
        |> Floki.parse_document!()

      html = Floki.raw_html(document)

      assert html =~ ~s(id="admin-console-motd-current")
      assert html =~ "Current admin console MOTD"
      assert html =~ ~s(id="admin-console-motd-form")
      assert html =~ ~s(phx-submit="admin_console_set_motd")
      assert html =~ ~s(name="motd")
      assert html =~ "Set MOTD"
      assert html =~ "Clear MOTD"
      assert html =~ "Refresh"
    end

    test "admin can set and clear MOTD from the structured tab", %{conn: conn} do
      view = connect_admin(conn)
      new_motd = "motd-admin-tab-#{uid()}"

      Application.put_env(:retro_hex_chat, :motd_cache, "Existing MOTD")

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      html = render_click(view, "admin_console_tab", %{"tab" => "motd"})

      assert html =~ "Existing MOTD"

      html =
        view
        |> form("#admin-console-motd-form", %{motd: new_motd})
        |> render_submit()

      assert html =~ "MOTD has been updated."
      assert html =~ new_motd
      assert Application.get_env(:retro_hex_chat, :motd_cache) == new_motd

      html = render_click(view, "admin_console_clear_motd")

      assert html =~ "MOTD has been cleared."
      assert html =~ "No MOTD has been set."
      assert Application.get_env(:retro_hex_chat, :motd_cache) == :unset
    end
  end

  describe "Admin Console Broadcast tab" do
    test "component renders wallops and announce controls" do
      document =
        render_component(&AdminConsoleDialog.admin_console_dialog/1,
          id: "admin-console-dialog",
          show: true,
          active_tab: "broadcast",
          results: [],
          broadcast_result: nil,
          broadcast_can_wallops: true,
          broadcast_can_announce: true,
          on_tab: "admin_console_tab",
          on_broadcast_send: "admin_console_send_broadcast",
          on_close: "close_admin_console"
        )
        |> Floki.parse_document!()

      html = Floki.raw_html(document)

      assert html =~ ~s(id="admin-console-broadcast-form")
      assert html =~ ~s(phx-submit="admin_console_send_broadcast")
      assert html =~ ~s(name="broadcast_type")
      assert html =~ ~s(value="wallops")
      assert html =~ ~s(value="announce")
      assert html =~ ~s(name="message")
      assert html =~ "Wallops"
      assert html =~ "Announce"
      assert html =~ "Send broadcast"
    end

    test "admin can send wallops and announcements from the structured tab", %{conn: conn} do
      view = connect_admin(conn)
      wallops = "wallops-admin-tab-#{uid()}"
      announcement = "announce-admin-tab-#{uid()}"

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:wallops")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:announcements")

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      render_click(view, "admin_console_tab", %{"tab" => "broadcast"})

      html =
        view
        |> form("#admin-console-broadcast-form", %{
          "broadcast_type" => "wallops",
          "message" => wallops
        })
        |> render_submit()

      assert html =~ "Wallops sent."
      assert_receive {:wallops, %{sender: "TestAdmin", content: ^wallops}}

      html =
        view
        |> form("#admin-console-broadcast-form", %{
          "broadcast_type" => "announce",
          "message" => announcement
        })
        |> render_submit()

      assert html =~ "Announcement sent to all users."
      assert_receive {:announcement, %{sender: "TestAdmin", content: ^announcement}}
    end
  end

  describe "Admin Console TURN tab" do
    test "component renders read-only stats, allocations, and refresh control" do
      document =
        render_component(&AdminConsoleDialog.admin_console_dialog/1,
          id: "admin-console-dialog",
          show: true,
          active_tab: "turn",
          results: [],
          turn_stats: "*** TURN Server Stats ***",
          turn_allocations: "*** No active TURN allocations.",
          turn_result: nil,
          turn_can_refresh: true,
          on_tab: "admin_console_tab",
          on_turn_refresh: "admin_console_refresh_turn",
          on_close: "close_admin_console"
        )
        |> Floki.parse_document!()

      html = Floki.raw_html(document)

      assert html =~ ~s(data-testid="admin-console-tab-turn")
      assert html =~ ~s(id="admin-console-turn-stats")
      assert html =~ "*** TURN Server Stats ***"
      assert html =~ ~s(id="admin-console-turn-allocations")
      assert html =~ "*** No active TURN allocations."
      assert html =~ ~s(phx-click="admin_console_refresh_turn")
      assert html =~ "Refresh"
    end

    test "admin can refresh TURN snapshots from the structured tab", %{conn: conn} do
      view = connect_admin(conn)

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      html = render_click(view, "admin_console_tab", %{"tab" => "turn"})

      assert_turn_snapshot(html)

      html = render_click(view, "admin_console_refresh_turn")

      assert_turn_snapshot(html)
    end
  end

  describe "Admin Console Audit Log tab" do
    test "component renders filters, audit output, and refresh control" do
      document =
        render_component(&AdminConsoleDialog.admin_console_dialog/1,
          id: "admin-console-dialog",
          show: true,
          active_tab: "audit_log",
          results: [],
          audit_log_text: "*** Audit Log (1 entries) ***",
          audit_log_last: "20",
          audit_log_user: "",
          audit_log_result: nil,
          audit_log_can_refresh: true,
          on_tab: "admin_console_tab",
          on_audit_log_refresh: "admin_console_refresh_audit_log",
          on_close: "close_admin_console"
        )
        |> Floki.parse_document!()

      html = Floki.raw_html(document)

      assert html =~ ~s(data-testid="admin-console-tab-audit-log")
      assert html =~ ~s(id="admin-console-audit-log-form")
      assert html =~ ~s(phx-submit="admin_console_refresh_audit_log")
      assert html =~ ~s(name="last")
      assert html =~ ~s(name="user")
      assert html =~ ~s(id="admin-console-audit-log-output")
      assert html =~ "*** Audit Log (1 entries) ***"
      assert html =~ "Refresh"
    end

    test "admin can refresh audit log snapshots with filters", %{conn: conn} do
      action = "audit.tab.#{uid()}"
      AuditLogs.log("TestAdmin", action, {"server", "settings"}, %{source: "feature-test"})

      view = connect_admin(conn)

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      html = render_click(view, "admin_console_tab", %{"tab" => "audit_log"})

      assert html =~ action

      html =
        view
        |> form("#admin-console-audit-log-form", %{
          "last" => "5",
          "user" => "TestAdmin"
        })
        |> render_submit()

      assert html =~ action
      assert html =~ "Audit Log"
    end
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp connect_admin(conn) do
    {:ok, view, _html} = live(chat_conn(conn, "TestAdmin", pre_identified: true), "/chat")
    view
  end

  defp tab_labels(document) do
    document
    |> Floki.find("[data-testid^=\"admin-console-tab-label-\"]")
    |> Enum.map(fn label -> label |> Floki.text() |> String.trim() end)
  end

  defp assert_turn_snapshot(html) do
    not_configured? = html =~ "TURN server is not configured" and html =~ "listener_count = 0"
    running? = html =~ "TURN Server Stats" and html =~ "Active allocations"

    assert not_configured? or running?
  end

  defp menu_actions(section) do
    section
    |> Floki.find("[data-testid^=\"context-menu-item-\"]")
    |> Enum.map(fn item ->
      item
      |> Floki.attribute("data-testid")
      |> List.first()
      |> String.replace_prefix("context-menu-item-", "")
    end)
  end
end
