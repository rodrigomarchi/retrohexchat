defmodule RetroHexChatWeb.ChatLive.Components.DeleteConfirmDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.DeleteConfirmDialog

  @moduletag :unit

  test "opens for a message id and carries it on confirm" do
    html =
      render_component(DeleteConfirmDialog, id: DeleteConfirmDialog.id(), action: {:open, 42})

    assert html =~ "Delete Message"
    assert html =~ ~s(data-testid="delete-confirm-dialog-confirm")
    # The confirm click pushes confirm_delete carrying the target message id.
    assert html =~ "confirm_delete"
    assert html =~ "42"
  end
end
