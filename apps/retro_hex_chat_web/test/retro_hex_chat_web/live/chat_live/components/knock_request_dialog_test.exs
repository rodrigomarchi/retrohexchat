defmodule RetroHexChatWeb.ChatLive.Components.KnockRequestDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.KnockRequestDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert KnockRequestDialog.id() == "knock-request-dialog"
  end

  test "renders hidden by default" do
    html = render_component(KnockRequestDialog, id: KnockRequestDialog.id())

    assert html =~ "Request Channel Access"
    assert html =~ "hidden"
  end

  test "opts the form out of reconnect form recovery" do
    # The dialog markup always sits in the DOM (just hidden). On a deploy
    # reconnect LiveView re-fires phx-change for every mounted form to recover
    # in-flight input; without this opt-out the hidden knock form's change event
    # fired on every reconnect and popped a spurious channel request window.
    html = render_component(KnockRequestDialog, id: KnockRequestDialog.id())

    assert html =~ ~s(phx-auto-recover="ignore")
  end

  test "opens for a channel with a cleared draft" do
    html =
      render_component(KnockRequestDialog,
        id: KnockRequestDialog.id(),
        visible: true,
        action: {:open, "#secret"}
      )

    assert html =~ "#secret"
    assert html =~ "Message (optional)"
    assert html =~ ~s(data-testid="knock-request-submit")
    assert html =~ ~s(phx-click="knock_request_cancel")
  end

  test "shows the typed message and an error" do
    html =
      render_component(KnockRequestDialog,
        id: KnockRequestDialog.id(),
        visible: true,
        action: {:error, "let me in", "Channel does not exist"}
      )

    assert html =~ "let me in"
    assert html =~ ~s(data-testid="knock-request-error")
    assert html =~ "Channel does not exist"
  end
end
