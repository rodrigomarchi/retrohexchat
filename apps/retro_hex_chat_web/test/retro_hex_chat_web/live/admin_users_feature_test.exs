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
  alias RetroHexChatWeb.Components.UI.StartMenuApp

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
      {:ok, view, _html} = live(chat_conn(conn, "Plain#{uid()}"), "/")

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
    {:ok, view, _html} = live(chat_conn(conn, "TestAdmin", pre_identified: true), "/")
    view
  end

  defp open_users(view) do
    render_click(view, "toolbar_action", %{"action" => "open_admin_users"})
    render(view)
  end
end
