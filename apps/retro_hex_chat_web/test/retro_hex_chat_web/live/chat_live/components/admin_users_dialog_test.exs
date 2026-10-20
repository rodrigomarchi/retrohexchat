defmodule RetroHexChatWeb.ChatLive.Components.AdminUsersDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :unit

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Components.AdminUsersDialog

  defp island(assigns) do
    session = %Session{
      Session.new("TestAdmin")
      | identified: true
    }

    render_component(
      AdminUsersDialog,
      Map.merge(%{id: AdminUsersDialog.id(), session: session}, assigns)
    )
  end

  test "routes every action to itself rather than the parent LiveView" do
    html = island(%{})

    assert html =~ ~s(phx-target=)
    assert html =~ ~s(phx-submit="admin_users_refresh")
    assert html =~ ~s(phx-submit="admin_users_ban")
    assert html =~ ~s(phx-submit="admin_users_ns_resetpass")
  end

  test "loads the user list on mount rather than waiting for an open directive" do
    # The window is server-managed: mounting IS opening, so the snapshot has to
    # be there on the first render. The pane renders the listing as rows, so its
    # table element is what proves the load ran.
    html = island(%{})

    assert [pane] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find("#admin-users-output")

    assert [_table] = Floki.find(pane, ~s([data-testid="admin-users-table"]))
  end

  test "reserves the admin role option for root admins" do
    html = island(%{})

    assert html =~ ~s(value="admin" disabled)
  end
end
