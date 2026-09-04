defmodule RetroHexChatWeb.AdminUsersFeatureTest do
  @moduledoc """
  Behaviour contract for the Admin Users window.

  Migrated from the Admin Console's Users tab when it was split into its own
  window: the assertions are unchanged, only the way the surface is opened and
  the element ids. A change in what these assert means the feature moved, not
  just its markup.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Admin.{GlobalMutes, ServerBans}
  alias RetroHexChat.Services.Queries
  alias RetroHexChatWeb.Components.UI.{AdminUsersDialog, StartMenuApp}

  describe "Admin Users panel" do
    test "renders user filters, snapshots, ban list, and every action form" do
      html =
        render_component(&AdminUsersDialog.admin_users_panel/1,
          id: "admin-users-dialog",
          text: "*** User List (1 results) ***\n  AdminUser [registered] [offline]",
          banlist_text: "*** No active server bans.",
          result: nil,
          search: "Admin",
          online_only: true,
          info_nick: "AdminUser",
          can_refresh: true,
          can_set_admin_role: false,
          on_refresh: "admin_users_refresh",
          on_info: "admin_users_info",
          on_ban: "admin_users_ban",
          on_unban: "admin_users_unban",
          on_kick: "admin_users_kick",
          on_mute: "admin_users_mute",
          on_unmute: "admin_users_unmute",
          on_rename: "admin_users_rename",
          on_role: "admin_users_role",
          on_ns_info: "admin_users_ns_info",
          on_ns_drop: "admin_users_ns_drop",
          on_ns_resetpass: "admin_users_ns_resetpass"
        )

      assert html =~ ~s(data-testid="admin-users-panel")
      assert html =~ ~s(id="admin-users-search-form")
      assert html =~ ~s(phx-submit="admin_users_refresh")
      assert html =~ ~s(name="search")
      assert html =~ ~s(name="online_only")
      assert html =~ ~s(id="admin-users-output")
      assert html =~ "AdminUser"
      assert html =~ ~s(id="admin-users-banlist")
      assert html =~ "No active server bans"
      assert html =~ ~s(id="admin-users-info-form")
      assert html =~ ~s(phx-submit="admin_users_info")
      assert html =~ ~s(name="nick")
      assert html =~ ~s(id="admin-users-ban-form")
      assert html =~ ~s(phx-submit="admin_users_ban")
      assert html =~ ~s(id="admin-users-unban-form")
      assert html =~ ~s(phx-submit="admin_users_unban")
      assert html =~ ~s(id="admin-users-kick-form")
      assert html =~ ~s(phx-submit="admin_users_kick")
      assert html =~ ~s(id="admin-users-mute-form")
      assert html =~ ~s(phx-submit="admin_users_mute")
      assert html =~ ~s(id="admin-users-unmute-form")
      assert html =~ ~s(phx-submit="admin_users_unmute")
      assert html =~ ~s(name="reason")
      assert html =~ ~s(name="duration")
      assert html =~ ~s(id="admin-users-rename-form")
      assert html =~ ~s(phx-submit="admin_users_rename")
      assert html =~ ~s(name="old_nick")
      assert html =~ ~s(name="new_nick")
      assert html =~ ~s(id="admin-users-role-form")
      assert html =~ ~s(phx-submit="admin_users_role")
      assert html =~ ~s(name="role")
      assert html =~ ~s(value="admin" disabled)
      assert html =~ ~s(id="admin-users-ns-info-form")
      assert html =~ ~s(phx-submit="admin_users_ns_info")
      assert html =~ ~s(id="admin-users-ns-resetpass-form")
      assert html =~ ~s(phx-submit="admin_users_ns_resetpass")
      assert html =~ ~s(name="new_password")
      assert html =~ ~s(id="admin-users-ns-drop-form")
      assert html =~ ~s(phx-submit="admin_users_ns_drop")
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
  end

  describe "Admin Users window" do
    test "admin can refresh users and inspect a nick", %{conn: conn} do
      nick = registered_nick("AU")

      view = connect_admin(conn)
      open_users(view)

      html = render(view)

      # The window renders rows now, not the command's text block.
      assert html =~ ~s(data-testid="admin-users-table")
      assert html =~ ~s(data-row-id="#{nick}")
      assert html =~ nick
      assert html =~ "No active server bans"

      view
      |> form("#admin-users-info-form", %{"nick" => nick})
      |> render_submit()

      html = render(view)

      assert html =~ "*** User: #{nick}"
      assert html =~ "Registered:"
      assert html =~ "Server operator:"
    end

    test "admin can apply user moderation actions", %{conn: conn} do
      nick = registered_nick("UM")

      view = connect_admin(conn)
      open_users(view)

      view
      |> form("#admin-users-ban-form", %{
        "nick" => nick,
        "reason" => "flooding",
        "duration" => "30m"
      })
      |> render_submit()

      html = render(view)

      assert html =~ "#{nick} has been server-banned"
      assert Enum.any?(ServerBans.all_active_bans(), &(&1.nickname == nick))

      view
      |> form("#admin-users-unban-form", %{"nick" => nick})
      |> render_submit()

      html = render(view)

      assert html =~ "#{nick} has been unbanned from the server."
      refute Enum.any?(ServerBans.all_active_bans(), &(&1.nickname == nick))

      view
      |> form("#admin-users-mute-form", %{"nick" => nick, "duration" => "15m"})
      |> render_submit()

      html = render(view)

      assert html =~ "#{nick} has been muted"
      assert GlobalMutes.muted?(nick)

      view
      |> form("#admin-users-unmute-form", %{"nick" => nick})
      |> render_submit()

      html = render(view)

      assert html =~ "#{nick} has been unmuted."
      refute GlobalMutes.muted?(nick)

      view
      |> form("#admin-users-kick-form", %{"nick" => nick, "reason" => "cleanup"})
      |> render_submit()

      html = render(view)

      assert html =~ "#{nick} has been kicked from the server."
    end

    test "admin can rename, assign roles, and run NickServ admin actions", %{conn: conn} do
      nick = registered_nick("UA")
      new_nick = "UB#{uid()}" |> String.slice(0, 16)

      view = connect_admin(conn)
      open_users(view)

      view
      |> form("#admin-users-rename-form", %{"old_nick" => nick, "new_nick" => new_nick})
      |> render_submit()

      html = render(view)

      assert html =~ "#{nick} has been renamed to #{new_nick}."

      view
      |> form("#admin-users-role-form", %{"nick" => nick, "role" => "server_operator"})
      |> render_submit()

      html = render(view)

      assert html =~ "#{nick} has been set as server_operator."

      view
      |> form("#admin-users-role-form", %{"nick" => nick, "role" => "user"})
      |> render_submit()

      html = render(view)

      assert html =~ "Admin roles removed from #{nick}."

      view
      |> form("#admin-users-ns-info-form", %{"nick" => nick})
      |> render_submit()

      html = render(view)

      assert html =~ "[NickServ] #{nick}"
      assert html =~ "Registered:"

      view
      |> form("#admin-users-ns-resetpass-form", %{
        "nick" => nick,
        "new_password" => "newpass123"
      })
      |> render_submit()

      html = render(view)

      assert html =~ "Password for #{nick} has been reset"

      view
      |> form("#admin-users-ns-drop-form", %{"nick" => nick})
      |> render_submit()

      html = render(view)

      assert html =~ "Registration for #{nick} dropped by admin"
      assert Queries.find_by_nickname(nick) == nil
    end
  end

  describe "Admin Users entry points and gating" do
    test "the Start menu's Admin group offers the window" do
      # Server administration opens programs of its own; it is reached from the
      # Start menu, not from the chat window's File menu.
      html =
        render_component(&StartMenuApp.start_menu_app/1,
          screen: :chat,
          windows: [],
          is_admin: true
        )

      assert html =~ ~s(data-testid="start-menu-admin-submenu")
      assert html =~ ~s(data-testid="start-menu-item-open_admin_users")
    end

    test "a non-admin does not see the entry" do
      doc =
        render_component(&StartMenuApp.start_menu_app/1, screen: :chat, windows: [])
        |> Floki.parse_document!()

      row = Floki.find(doc, ~s([data-testid="start-menu-item-open_admin_users"]))

      assert row == []
    end

    test "opening mounts a managed window and closing unmounts it", %{conn: conn} do
      view = connect_admin(conn)

      refute has_element?(view, ~s([data-window-id="admin-users"]))

      open_users(view)

      assert has_element?(view, ~s([data-window-id="admin-users"][data-window-managed="true"]))
      assert_push_event(view, "window_command", %{action: "open", id: "admin-users"})

      render_hook(view, "window_closed", %{"id" => "admin-users"})

      refute has_element?(view, ~s([data-window-id="admin-users"]))
    end

    test "a forged window_open renders nothing for a non-admin", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Plain#{uid()}"), "/chat")

      render_hook(view, "window_open", %{"id" => "admin-users"})

      refute has_element?(view, ~s([data-testid="admin-users-panel"]))
    end
  end

  defp registered_nick(prefix) do
    nick = "#{prefix}#{uid()}" |> String.slice(0, 16)
    assert {:ok, _registered} = Queries.insert_registered_nick(nick, "password123")
    nick
  end

  defp connect_admin(conn) do
    {:ok, view, _html} = live(chat_conn(conn, "TestAdmin", pre_identified: true), "/chat")
    view
  end

  defp open_users(view) do
    render_click(view, "toolbar_action", %{"action" => "open_admin_users"})
    render(view)
  end
end
