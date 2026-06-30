defmodule RetroHexChatWeb.ChatLive.Components.AdminConsoleDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog

  @moduletag :unit

  defp dialog(overrides) do
    assigns = Map.merge(%{id: AdminConsoleDialog.id()}, overrides)
    render_component(AdminConsoleDialog, assigns)
  end

  test "exposes a stable id" do
    assert AdminConsoleDialog.id() == "admin-console-dialog"
  end

  test "renders only the (empty) mount wrapper when closed (show defaults false)" do
    html = dialog(%{})

    assert html =~ ~s(id="admin-console-dialog-mount")
    refute html =~ ~s(data-testid="admin-console-output")
  end

  test "renders the console output area by default when shown" do
    html = dialog(%{show: true})

    assert html =~ ~s(id="admin-console-dialog")
    assert html =~ "Admin Console"
    assert html =~ ~s(data-testid="admin-console-output")
  end

  test "renders the active tab content from owned display assigns" do
    html =
      dialog(%{
        show: true,
        active_tab: "users",
        users_text: "*** User List (1 results) ***\n  AdminUser",
        users_search: "Admin",
        is_admin: true,
        admin_only: true
      })

    assert html =~ ~s(data-testid="admin-console-tab-users")
    assert html =~ "AdminUser"
    assert html =~ ~s(phx-submit="admin_console_refresh_users")
  end

  test "derives the per-control permission flags from the three permission booleans" do
    # admin_only grants the role form but only root_admin may set the admin role
    html =
      dialog(%{
        show: true,
        active_tab: "users",
        is_admin: true,
        admin_only: true,
        root_admin: false
      })

    assert html =~ ~s(phx-submit="admin_console_user_role")
    # admin role option is disabled when the viewer is not a root admin
    assert html =~ ~s(value="admin" disabled)
  end

  test "passes through the read-model filter drafts" do
    html = dialog(%{show: true, active_tab: "channels", channels_search: "#lobby-search"})

    assert html =~ "#lobby-search"
  end
end
