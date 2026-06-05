defmodule RetroHexChatWeb.ServerAdministrationFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.HelpTopics
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
      assert "motd tab" in admin_console.keywords
      assert "danger zone" in admin_console.keywords
      assert "cmd-setmotd" in admin_console.see_also
      assert "cmd-clearmotd" in admin_console.see_also
      assert "cmd-admin-nuke" in admin_console.see_also
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
