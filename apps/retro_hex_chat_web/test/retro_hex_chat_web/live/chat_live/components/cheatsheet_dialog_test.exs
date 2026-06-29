defmodule RetroHexChatWeb.ChatLive.Components.CheatsheetDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.CheatsheetDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert CheatsheetDialog.id() == "cheatsheet-dialog"
  end

  test "is hidden by default (no show-trigger)" do
    html = render_component(CheatsheetDialog, id: CheatsheetDialog.id())

    assert html =~ ~s(data-testid="cheatsheet-dialog")
    refute html =~ "cheatsheet-dialog-show-trigger"
  end

  test "renders the static bindings table when visible" do
    html = render_component(CheatsheetDialog, id: CheatsheetDialog.id(), visible: true)

    assert html =~ "cheatsheet-dialog-show-trigger"
    assert html =~ "Keyboard Shortcuts"
    # Close bubbles to the parent's Escape-managed toggle.
    assert html =~ "toggle_cheatsheet"
  end
end
