defmodule RetroHexChatWeb.ChatLive.Components.NickChangeDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.NickChangeDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert NickChangeDialog.id() == "nick-change-dialog"
  end

  test "renders hidden by default" do
    html = render_component(NickChangeDialog, id: NickChangeDialog.id())

    assert html =~ ~s(data-testid="nick-change-dialog")
    assert html =~ "hidden"
  end

  test "opens for an unregistered nick (no password field)" do
    html =
      render_component(NickChangeDialog,
        id: NickChangeDialog.id(),
        action: {:open, %{target_nick: "bob", registered: false}}
      )

    assert html =~ "bob"
    # Confirm bubbles to the parent carrying target + registered.
    assert html =~ "confirm_nick_change"
    assert html =~ "nick_change_cancel"
    refute html =~ ~s(data-testid="nick-change-password")
  end

  test "opens for a registered nick with a password field" do
    html =
      render_component(NickChangeDialog,
        id: NickChangeDialog.id(),
        action: {:open, %{target_nick: "alice", registered: true}}
      )

    assert html =~ "alice"
    assert html =~ ~s(data-testid="nick-change-password")
    assert html =~ "NickServ password"
  end
end
