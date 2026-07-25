defmodule RetroHexChatWeb.AdminWindowsFeatureTest do
  @moduledoc """
  Behaviour contract for the smaller admin windows and the Console.

  Migrated from the Admin Console's tabs when they were split into their own
  windows: the assertions are unchanged, only the way each surface is opened and
  the element ids.

  These windows are one or two tests each, so they share a file rather than each
  getting one of their own. The heavier surfaces — Users and Channels — have
  their own suites.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Services.Queries
  alias RetroHexChatWeb.Components.UI.{MenuBarApp, StartMenuApp, ToolbarApp}

  setup do
    Application.put_env(:retro_hex_chat, :motd_cache, :unset)
    on_exit(fn -> Application.put_env(:retro_hex_chat, :motd_cache, :unset) end)
    :ok
  end

  describe "Server Settings window" do
    test "admin can read and save server settings", %{conn: conn} do
      original = Queries.get_setting("server_description")
      initial = "server-settings-initial-#{uid()}"
      updated = "server-settings-updated-#{uid()}"

      Queries.upsert_setting("server_description", initial, "TestSeed")

      on_exit(fn ->
        if original do
          Queries.upsert_setting("server_description", original, "TestSeed")
        else
          Queries.delete_setting("server_description")
        end
      end)

      view = connect_admin(conn)
      open(view, "admin_server_settings")

      assert render(view) =~ initial

      view
      |> form("#admin-server-settings-form", %{"server_description" => updated})
      |> render_submit()

      html = render(view)

      assert html =~ "Server setting &#39;server_description&#39; set to"
      assert html =~ updated
      assert Queries.get_setting("server_description") == updated
    end
  end

  describe "MOTD window" do
    test "admin can set and clear the MOTD", %{conn: conn} do
      view = connect_admin(conn)
      new_motd = "motd-window-#{uid()}"

      Application.put_env(:retro_hex_chat, :motd_cache, "Existing MOTD")

      open(view, "admin_motd")
      assert render(view) =~ "Existing MOTD"

      view |> form("#admin-motd-form", %{motd: new_motd}) |> render_submit()

      html = render(view)

      assert html =~ "MOTD has been updated."
      assert html =~ new_motd
      assert Application.get_env(:retro_hex_chat, :motd_cache) == new_motd

      click(view, "admin_motd_clear")
      html = render(view)

      assert html =~ "MOTD has been cleared."
      assert html =~ "No MOTD has been set."
      assert Application.get_env(:retro_hex_chat, :motd_cache) == :unset
    end
  end

  describe "Broadcast window" do
    test "admin can send wallops and announcements", %{conn: conn} do
      view = connect_admin(conn)
      wallops = "wallops-window-#{uid()}"
      announcement = "announce-window-#{uid()}"

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:wallops")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:announcements")

      open(view, "admin_broadcast")

      view
      |> form("#admin-broadcast-form", %{"broadcast_type" => "wallops", "message" => wallops})
      |> render_submit()

      assert render(view) =~ "Wallops sent."
      assert_receive {:wallops, %{sender: "TestAdmin", content: ^wallops}}

      view
      |> form("#admin-broadcast-form", %{
        "broadcast_type" => "announce",
        "message" => announcement
      })
      |> render_submit()

      assert render(view) =~ "Announcement sent to all users."
      assert_receive {:announcement, %{sender: "TestAdmin", content: ^announcement}}
    end
  end

  describe "TURN window" do
    test "admin can read and refresh the relay snapshot", %{conn: conn} do
      view = connect_admin(conn)

      open(view, "admin_turn")
      assert_turn_snapshot(render(view))

      click(view, "admin_turn_refresh")
      assert_turn_snapshot(render(view))
    end
  end

  describe "Audit Log window" do
    test "admin can read and filter the log", %{conn: conn} do
      action = "audit.window.#{uid()}"
      AuditLogs.log("TestAdmin", action, {"server", "settings"}, %{source: "feature-test"})

      view = connect_admin(conn)
      open(view, "admin_audit_log")

      assert render(view) =~ action

      view
      |> form("#admin-audit-log-form", %{"last" => "5", "user" => "TestAdmin"})
      |> render_submit()

      html = render(view)

      assert html =~ action
      assert html =~ "Audit Log"
    end
  end

  describe "Danger Zone window" do
    test "the preview loads and a wrong confirmation is refused", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "admin_danger_zone")

      html = render(view)

      assert html =~ "NUKE PREVIEW"
      assert html =~ "Preserved"

      view
      |> form("#admin-danger-zone-form", %{"confirm" => "wrong-server"})
      |> render_submit()

      html = render(view)

      assert html =~ "Type the server name to confirm."
      assert html =~ "NUKE PREVIEW"
    end
  end

  describe "Console window" do
    test "admin can run a batch command and clear the transcript", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "admin_console")

      assert has_element?(view, "#admin-console-input")

      view
      |> form("#admin-console-form", %{"input" => "/admin server get registration"})
      |> render_submit()

      assert render(view) =~ "registration"

      click(view, "admin_console_clear")

      assert render(view) =~ "Type a command and press Enter."
    end

    test "a line that is not a command is reported, not dispatched", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "admin_console")

      view
      |> form("#admin-console-form", %{"input" => "not a command"})
      |> render_submit()

      assert render(view) =~ "Not a command (must start with /)"
    end
  end

  describe "Entry points and gating" do
    # Three separate surfaces list these windows. A window added to one and
    # forgotten in the others is invisible from there, and nothing else catches
    # it — so each surface is asserted against the same list.
    test "every admin surface offers every admin window" do
      for {surface, html} <- admin_surfaces(true) do
        for action <- admin_actions() do
          assert html =~ ~s(data-testid="context-menu-item-#{action}") or
                   html =~ ~s(data-testid="start-menu-item-#{action}"),
                 "#{surface} should offer #{action}"
        end
      end
    end

    test "non-admins see none of them, on any surface" do
      for {surface, html} <- admin_surfaces(false) do
        for action <- admin_actions() do
          refute html =~ ~s(data-testid="context-menu-item-#{action}"),
                 "#{surface} must not offer #{action} to a non-admin"

          refute html =~ ~s(data-testid="start-menu-item-#{action}"),
                 "#{surface} must not offer #{action} to a non-admin"
        end
      end
    end

    test "every admin window opens as a managed window and closes cleanly", %{conn: conn} do
      view = connect_admin(conn)

      for action <- admin_actions() do
        id = String.replace_prefix(action, "open_", "") |> String.replace("_", "-")

        refute has_element?(view, ~s([data-window-id="#{id}"])),
               "#{id} should not be mounted before opening"

        render_click(view, "toolbar_action", %{"action" => action})

        assert has_element?(view, ~s([data-window-id="#{id}"][data-window-managed="true"])),
               "#{id} should mount as a managed window"

        render_hook(view, "window_closed", %{"id" => id})

        refute has_element?(view, ~s([data-window-id="#{id}"])),
               "#{id} should unmount when closed"
      end
    end

    test "a non-admin is refused, and a forged window_open renders nothing", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Rando#{uid()}"), "/chat")

      # The refusal is bubbled to the chat surface, so it lands on the render
      # after the click rather than in the click's own result.
      html = open(view, "admin_console")

      refute html =~ ~s(data-testid="admin-console-window")
      assert html =~ "restricted to server administrators"

      for action <- admin_actions() do
        id = String.replace_prefix(action, "open_", "") |> String.replace("_", "-")
        render_hook(view, "window_open", %{"id" => id})

        refute has_element?(view, ~s([data-testid="#{id}-panel"])),
               "#{id} must stay out of a non-admin's DOM"
      end
    end
  end

  defp admin_surfaces(is_admin?) do
    [
      {"menu bar",
       render_component(&MenuBarApp.menu_bar_app/1,
         connected: true,
         is_admin: is_admin?,
         on_action: "toolbar_action"
       )},
      {"start menu",
       render_component(&StartMenuApp.start_menu_app/1,
         is_admin: is_admin?,
         on_action: "toolbar_action"
       )},
      {"toolbar",
       render_component(&ToolbarApp.toolbar_app/1,
         connected: true,
         is_admin: is_admin?,
         on_action: "toolbar_action"
       )}
    ]
  end

  defp admin_actions do
    ~w(
      open_admin_users
      open_admin_channels
      open_admin_server_settings
      open_admin_audit_log
      open_admin_motd
      open_admin_turn
      open_admin_broadcast
      open_admin_danger_zone
      open_admin_console
    )
  end

  defp connect_admin(conn) do
    {:ok, view, _html} = live(chat_conn(conn, "TestAdmin", pre_identified: true), "/chat")
    view
  end

  defp open(view, action) do
    render_click(view, "toolbar_action", %{"action" => "open_#{action}"})
    render(view)
  end

  defp click(view, event) do
    view |> element("[phx-click='#{event}']") |> render_click()
  end

  defp assert_turn_snapshot(html) do
    not_configured? = html =~ "TURN server is not configured" and html =~ "listener_count = 0"
    running? = html =~ "TURN Server Stats" and html =~ "Active allocations"

    assert not_configured? or running?
  end
end
