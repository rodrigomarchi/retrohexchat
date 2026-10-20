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

  # The empty transcript used to say `Type "help"`, and the console refuses
  # anything without a leading slash — the invitation walked the reader into
  # the one error the window can produce before they have done anything.
  test "invites a first command while the transcript is empty" do
    html = island(%{})

    assert html =~ "Every command starts with a slash"
    assert html =~ "/admin"
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
