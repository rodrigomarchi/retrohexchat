defmodule RetroHexChatWeb.ChatLive.Components.AdminConsoleDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog

  @moduletag :unit

  # "TestAdmin" is in config/test.exs `admins:` → admin? + admin_only? true,
  # root_admin? false (not in root_admins). The component derives the per-control
  # permission flags from this session in render/1.
  defp admin_session, do: "TestAdmin" |> Session.new() |> Session.set_identified(true)

  defp dialog(overrides) do
    base = %{id: AdminConsoleDialog.id(), session: admin_session()}
    render_component(AdminConsoleDialog, Map.merge(base, overrides))
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
        users_search: "Admin"
      })

    assert html =~ ~s(data-testid="admin-console-tab-users")
    assert html =~ "AdminUser"
    assert html =~ ~s(phx-submit="admin_console_refresh_users")
  end

  test "derives the per-control permission flags from the session" do
    # admin_only (TestAdmin) grants the role form, but only root_admin may set
    # the admin role — TestAdmin is not a root admin, so the option is disabled.
    html = dialog(%{show: true, active_tab: "users"})

    assert html =~ ~s(phx-submit="admin_console_user_role")
    assert html =~ ~s(value="admin" disabled)
  end

  test "owns and renders the filter/draft read-model" do
    html = dialog(%{show: true, active_tab: "channels", channels_search: "#lobby-search"})

    assert html =~ "#lobby-search"
  end
end
