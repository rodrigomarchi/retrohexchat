defmodule RetroHexChatWeb.ChatLive.Components.PasteConfirmDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.PasteConfirmDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert PasteConfirmDialog.id() == "paste-confirm-dialog"
  end

  test "renders hidden with no pasted lines" do
    html = render_component(PasteConfirmDialog, id: PasteConfirmDialog.id())

    assert html =~ ~s(data-testid="paste-confirm-dialog")
    refute html =~ "paste-confirm-dialog-show-trigger"
  end

  test "shows after lines are set, with the flood warning" do
    lines = Enum.map(1..60, &"line #{&1}")

    html =
      render_component(PasteConfirmDialog,
        id: PasteConfirmDialog.id(),
        action: {:set, lines, true, false}
      )

    assert html =~ "paste-confirm-dialog-show-trigger"
    assert html =~ ~s(data-testid="paste-confirm-send")
    assert html =~ ~s(data-testid="paste-flood-warning")
  end
end
