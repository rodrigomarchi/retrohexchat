defmodule RetroHexChatWeb.ServerAdministrationFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Admin.{AuditLogs, GlobalMutes, ServerBans}
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
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
      assert "danger zone tab" in admin_console.keywords
      assert "users tab" in admin_console.keywords
      assert "channels tab" in admin_console.keywords
      assert "cmd-setmotd" in admin_console.see_also
      assert "cmd-clearmotd" in admin_console.see_also
      assert "cmd-admin-nuke" in admin_console.see_also

      admin_user = HelpTopics.get_topic("cmd-admin-user")

      assert "users tab" in admin_user.keywords
      assert "feature-admin-console" in admin_user.see_also

      admin_channel = HelpTopics.get_topic("cmd-admin-channel")

      assert "channels tab" in admin_channel.keywords
      assert "feature-admin-console" in admin_channel.see_also

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

  describe "Admin Console Users tab" do
    test "component renders user filters, snapshots, ban list, and info command controls" do
      document =
        render_component(&AdminConsoleDialog.admin_console_dialog/1,
          id: "admin-console-dialog",
          show: true,
          active_tab: "users",
          results: [],
          users_text: "*** User List (1 results) ***\n  AdminUser [registered] [offline]",
          users_banlist_text: "*** No active server bans.",
          users_result: nil,
          users_search: "Admin",
          users_online_only: true,
          users_info_nick: "AdminUser",
          users_can_refresh: true,
          users_can_set_admin_role: false,
          on_tab: "admin_console_tab",
          on_users_refresh: "admin_console_refresh_users",
          on_users_info: "admin_console_user_info",
          on_users_ban: "admin_console_user_ban",
          on_users_unban: "admin_console_user_unban",
          on_users_kick: "admin_console_user_kick",
          on_users_mute: "admin_console_user_mute",
          on_users_unmute: "admin_console_user_unmute",
          on_users_rename: "admin_console_user_rename",
          on_users_role: "admin_console_user_role",
          on_users_ns_info: "admin_console_user_ns_info",
          on_users_ns_drop: "admin_console_user_ns_drop",
          on_users_ns_resetpass: "admin_console_user_ns_resetpass",
          on_close: "close_admin_console"
        )
        |> Floki.parse_document!()

      html = Floki.raw_html(document)

      assert html =~ ~s(data-testid="admin-console-tab-users")
      assert html =~ ~s(id="admin-console-users-form")
      assert html =~ ~s(phx-submit="admin_console_refresh_users")
      assert html =~ ~s(name="search")
      assert html =~ ~s(name="online_only")
      assert html =~ ~s(id="admin-console-users-output")
      assert html =~ "AdminUser"
      assert html =~ ~s(id="admin-console-users-banlist")
      assert html =~ "No active server bans"
      assert html =~ ~s(id="admin-console-user-info-form")
      assert html =~ ~s(phx-submit="admin_console_user_info")
      assert html =~ ~s(name="nick")
      assert html =~ ~s(id="admin-console-user-ban-form")
      assert html =~ ~s(phx-submit="admin_console_user_ban")
      assert html =~ ~s(id="admin-console-user-unban-form")
      assert html =~ ~s(phx-submit="admin_console_user_unban")
      assert html =~ ~s(id="admin-console-user-kick-form")
      assert html =~ ~s(phx-submit="admin_console_user_kick")
      assert html =~ ~s(id="admin-console-user-mute-form")
      assert html =~ ~s(phx-submit="admin_console_user_mute")
      assert html =~ ~s(id="admin-console-user-unmute-form")
      assert html =~ ~s(phx-submit="admin_console_user_unmute")
      assert html =~ ~s(name="reason")
      assert html =~ ~s(name="duration")
      assert html =~ ~s(id="admin-console-user-rename-form")
      assert html =~ ~s(phx-submit="admin_console_user_rename")
      assert html =~ ~s(name="old_nick")
      assert html =~ ~s(name="new_nick")
      assert html =~ ~s(id="admin-console-user-role-form")
      assert html =~ ~s(phx-submit="admin_console_user_role")
      assert html =~ ~s(name="role")
      assert html =~ ~s(value="admin" disabled)
      assert html =~ ~s(id="admin-console-user-ns-info-form")
      assert html =~ ~s(phx-submit="admin_console_user_ns_info")
      assert html =~ ~s(id="admin-console-user-ns-resetpass-form")
      assert html =~ ~s(phx-submit="admin_console_user_ns_resetpass")
      assert html =~ ~s(name="new_password")
      assert html =~ ~s(id="admin-console-user-ns-drop-form")
      assert html =~ ~s(phx-submit="admin_console_user_ns_drop")
      assert html =~ "Refresh"
      assert html =~ "Info"
      assert html =~ "Confirm ban"
      assert html =~ "Confirm kick"
      assert html =~ "Confirm mute"
      assert html =~ "Rename"
      assert html =~ "Set role"
      assert html =~ "NickServ info"
      assert html =~ "Reset password"
      assert html =~ "Drop registration"
    end

    test "admin can refresh users and inspect a nick through the structured tab", %{conn: conn} do
      nick =
        "AU#{uid()}"
        |> String.slice(0, 16)

      assert {:ok, _registered} = Queries.insert_registered_nick(nick, "password123")

      view = connect_admin(conn)

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      html = render_click(view, "admin_console_tab", %{"tab" => "users"})

      assert html =~ "*** User List"
      assert html =~ nick
      assert html =~ "No active server bans"

      html =
        view
        |> form("#admin-console-user-info-form", %{"nick" => nick})
        |> render_submit()

      assert html =~ "*** User: #{nick}"
      assert html =~ "Registered:"
      assert html =~ "Server operator:"
    end

    test "admin can apply user moderation actions through the structured tab", %{conn: conn} do
      nick =
        "UM#{uid()}"
        |> String.slice(0, 16)

      assert {:ok, _registered} = Queries.insert_registered_nick(nick, "password123")

      view = connect_admin(conn)

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      render_click(view, "admin_console_tab", %{"tab" => "users"})

      html =
        view
        |> form("#admin-console-user-ban-form", %{
          "nick" => nick,
          "reason" => "flooding",
          "duration" => "30m"
        })
        |> render_submit()

      assert html =~ "#{nick} has been server-banned"
      assert Enum.any?(ServerBans.list_active_bans(), &(&1.nickname == nick))

      html =
        view
        |> form("#admin-console-user-unban-form", %{"nick" => nick})
        |> render_submit()

      assert html =~ "#{nick} has been unbanned from the server."
      refute Enum.any?(ServerBans.list_active_bans(), &(&1.nickname == nick))

      html =
        view
        |> form("#admin-console-user-mute-form", %{"nick" => nick, "duration" => "15m"})
        |> render_submit()

      assert html =~ "#{nick} has been muted"
      assert GlobalMutes.muted?(nick)

      html =
        view
        |> form("#admin-console-user-unmute-form", %{"nick" => nick})
        |> render_submit()

      assert html =~ "#{nick} has been unmuted."
      refute GlobalMutes.muted?(nick)

      html =
        view
        |> form("#admin-console-user-kick-form", %{"nick" => nick, "reason" => "cleanup"})
        |> render_submit()

      assert html =~ "#{nick} has been kicked from the server."
    end

    test "admin can rename, assign roles, and run NickServ admin actions from Users tab", %{
      conn: conn
    } do
      nick =
        "UA#{uid()}"
        |> String.slice(0, 16)

      new_nick =
        "UB#{uid()}"
        |> String.slice(0, 16)

      assert {:ok, _registered} = Queries.insert_registered_nick(nick, "password123")

      view = connect_admin(conn)

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      render_click(view, "admin_console_tab", %{"tab" => "users"})

      html =
        view
        |> form("#admin-console-user-rename-form", %{
          "old_nick" => nick,
          "new_nick" => new_nick
        })
        |> render_submit()

      assert html =~ "#{nick} has been renamed to #{new_nick}."

      html =
        view
        |> form("#admin-console-user-role-form", %{"nick" => nick, "role" => "server_operator"})
        |> render_submit()

      assert html =~ "#{nick} has been set as server_operator."

      html =
        view
        |> form("#admin-console-user-role-form", %{"nick" => nick, "role" => "user"})
        |> render_submit()

      assert html =~ "Admin roles removed from #{nick}."

      html =
        view
        |> form("#admin-console-user-ns-info-form", %{"nick" => nick})
        |> render_submit()

      assert html =~ "[NickServ] #{nick}"
      assert html =~ "Registered:"

      html =
        view
        |> form("#admin-console-user-ns-resetpass-form", %{
          "nick" => nick,
          "new_password" => "newpass123"
        })
        |> render_submit()

      assert html =~ "Password for #{nick} has been reset"

      html =
        view
        |> form("#admin-console-user-ns-drop-form", %{"nick" => nick})
        |> render_submit()

      assert html =~ "Registration for #{nick} dropped by admin"
      assert Queries.find_by_nickname(nick) == nil
    end
  end

  describe "Admin Console Channels tab" do
    test "component renders channel filters, snapshots, info, create, and banlist controls" do
      document =
        render_component(&AdminConsoleDialog.admin_console_dialog/1,
          id: "admin-console-dialog",
          show: true,
          active_tab: "channels",
          results: [],
          channels_text: "*** Channel List (1) ***\n  #admin (1 members)",
          channels_banlist_text: "*** No bans in #admin.",
          channels_result: nil,
          channels_search: "#adm",
          channels_info_channel: "#admin",
          channels_create_name: "#new-admin",
          channels_can_refresh: true,
          on_tab: "admin_console_tab",
          on_channels_refresh: "admin_console_refresh_channels",
          on_channels_info: "admin_console_channel_info",
          on_channels_create: "admin_console_channel_create",
          on_channels_delete: "admin_console_channel_delete",
          on_channels_purge: "admin_console_channel_purge",
          on_close: "close_admin_console"
        )
        |> Floki.parse_document!()

      html = Floki.raw_html(document)

      assert html =~ ~s(data-testid="admin-console-tab-channels")
      assert html =~ ~s(id="admin-console-channels-form")
      assert html =~ ~s(phx-submit="admin_console_refresh_channels")
      assert html =~ ~s(name="search")
      assert html =~ ~s(id="admin-console-channels-output")
      assert html =~ "#admin"
      assert html =~ ~s(id="admin-console-channel-info-form")
      assert html =~ ~s(phx-submit="admin_console_channel_info")
      assert html =~ ~s(name="channel")
      assert html =~ ~s(id="admin-console-channel-create-form")
      assert html =~ ~s(phx-submit="admin_console_channel_create")
      assert html =~ ~s(id="admin-console-channel-delete-form")
      assert html =~ ~s(phx-submit="admin_console_channel_delete")
      assert html =~ ~s(id="admin-console-channel-purge-form")
      assert html =~ ~s(phx-submit="admin_console_channel_purge")
      assert html =~ ~s(name="confirm")
      assert html =~ ~s(name="from")
      assert html =~ ~s(id="admin-console-channels-banlist")
      assert html =~ "No bans in #admin"
      assert html =~ "Refresh"
      assert html =~ "Info"
      assert html =~ "Create"
      assert html =~ "Confirm delete"
      assert html =~ "Confirm purge"
    end

    test "admin can refresh channels, inspect a channel, and create a channel", %{conn: conn} do
      channel = "#ac#{uid()}"
      member = "ACM#{uid()}"
      new_channel = "#anc#{uid()}"

      ensure_channel(channel)
      assert {:ok, _state} = Server.join(channel, member)

      view = connect_admin(conn)

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      html = render_click(view, "admin_console_tab", %{"tab" => "channels"})

      assert html =~ "*** Channel List"
      assert html =~ channel

      html =
        view
        |> form("#admin-console-channel-info-form", %{"channel" => channel})
        |> render_submit()

      assert html =~ "*** Channel: #{channel}"
      assert html =~ "Members"
      assert html =~ "No bans in #{channel}"

      html =
        view
        |> form("#admin-console-channel-create-form", %{"channel" => new_channel})
        |> render_submit()

      assert html =~ "Channel #{new_channel} created and registered."
      assert html =~ new_channel
    end

    test "admin can purge and delete channels with typed confirmation", %{conn: conn} do
      channel = "#dc#{uid()}"

      ensure_channel(channel)

      view = connect_admin(conn)

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      render_click(view, "admin_console_tab", %{"tab" => "channels"})

      html =
        view
        |> form("#admin-console-channel-purge-form", %{
          "channel" => channel,
          "from" => "",
          "confirm" => channel
        })
        |> render_submit()

      assert html =~ "Purged 0 messages from #{channel}."

      html =
        view
        |> form("#admin-console-channel-delete-form", %{
          "channel" => channel,
          "confirm" => channel
        })
        |> render_submit()

      assert html =~ "Channel #{channel} has been deleted."
      assert Registry.lookup(channel) == {:error, :not_found}
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

  describe "Admin Console Danger Zone tab" do
    test "component renders nuke preview, server-name confirmation, and guarded execute button" do
      document =
        render_component(&AdminConsoleDialog.admin_console_dialog/1,
          id: "admin-console-dialog",
          show: true,
          active_tab: "danger_zone",
          results: [],
          danger_zone_preview: "*** NUKE PREVIEW — 3 records will be destroyed ***",
          danger_zone_result: nil,
          danger_zone_confirm: "",
          danger_zone_server_name: "RetroHexChat",
          danger_zone_can_execute: true,
          on_tab: "admin_console_tab",
          on_danger_zone_preview: "admin_console_preview_nuke",
          on_danger_zone_change: "admin_console_change_nuke_confirm",
          on_danger_zone_execute: "admin_console_execute_nuke",
          on_close: "close_admin_console"
        )
        |> Floki.parse_document!()

      html = Floki.raw_html(document)

      assert html =~ ~s(data-testid="admin-console-tab-danger-zone")
      assert html =~ ~s(id="admin-console-danger-preview")
      assert html =~ "NUKE PREVIEW"
      assert html =~ "Preserved"
      assert html =~ ~s(id="admin-console-danger-zone-form")
      assert html =~ ~s(phx-change="admin_console_change_nuke_confirm")
      assert html =~ ~s(phx-submit="admin_console_execute_nuke")
      assert html =~ ~s(name="confirm")
      assert html =~ "THIS CANNOT BE UNDONE"
      assert html =~ "NUKE EVERYTHING"
      assert html =~ "disabled"
    end

    test "admin can preview nuke and invalid confirmation is blocked", %{conn: conn} do
      view = connect_admin(conn)

      render_click(view, "toolbar_action", %{"action" => "open_admin_console"})
      html = render_click(view, "admin_console_tab", %{"tab" => "danger_zone"})

      assert html =~ "NUKE PREVIEW"
      assert html =~ "Preserved"

      html =
        view
        |> form("#admin-console-danger-zone-form", %{"confirm" => "wrong-server"})
        |> render_submit()

      assert html =~ "Type the server name to confirm."
      assert html =~ "NUKE PREVIEW"
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

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} ->
        :ok

      {:error, :not_found} ->
        case Supervisor.start_child(name) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end
    end
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
