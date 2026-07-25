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

  test "exposes a stable id the parent can send_update to" do
    assert AdminUsersDialog.id() == "admin-users-dialog"
  end

  test "renders the bare panel, with no dialog chrome of its own" do
    html = island(%{})

    assert html =~ ~s(data-testid="admin-users-panel")
    assert html =~ ~s(id="admin-users-dialog-content")
    refute html =~ ~s(role="dialog" aria-modal="true")
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
    # be there on the first render. The dispatcher always answers with a `***`
    # line, so an empty pane would mean the load never ran.
    html = island(%{})

    assert [pane] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find("#admin-users-output")

    assert pane |> Floki.text() |> String.starts_with?("***")
  end

  test "reserves the admin role option for root admins" do
    html = island(%{})

    assert html =~ ~s(value="admin" disabled)
  end
end
