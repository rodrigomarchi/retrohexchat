defmodule RetroHexChatWeb.ChatLive.Components.AdminConsoleDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :unit

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog

  defp island(assigns) do
    session = %Session{Session.new("TestAdmin") | identified: true}

    render_component(
      AdminConsoleDialog,
      Map.merge(%{id: AdminConsoleDialog.id(), session: session}, assigns)
    )
  end

  test "exposes a stable id the parent can send_update to" do
    assert AdminConsoleDialog.id() == "admin-console-dialog"
  end

  test "renders the bare panel, with no dialog chrome of its own" do
    html = island(%{})

    assert html =~ ~s(data-testid="admin-console-panel")
    assert html =~ ~s(id="admin-console-dialog-content")
    refute html =~ ~s(aria-modal="true")
  end

  test "renders the runner: an output transcript and a command input" do
    html = island(%{})

    assert html =~ ~s(data-testid="admin-console-output")
    assert html =~ ~s(id="admin-console-input")
    assert html =~ ~s(phx-submit="admin_console_run")
    assert html =~ ~s(phx-click="admin_console_clear")
  end

  test "invites a first command while the transcript is empty" do
    html = island(%{})

    assert html =~ "Type a command and press Enter."
  end

  test "renders a transcript entry with its echoed line" do
    html = island(%{results: [%{line: "/admin server info", status: :ok, message: "*** Server"}]})

    assert html =~ "/admin server info"
    assert html =~ "*** Server"
  end

  test "marks a failed line apart from a successful one" do
    ok = island(%{results: [%{line: "/ok", status: :ok, message: "fine"}]})
    err = island(%{results: [%{line: "/nope", status: :error, message: "boom"}]})

    assert ok =~ "text-green-400"
    assert err =~ "text-red-400"
  end
end
