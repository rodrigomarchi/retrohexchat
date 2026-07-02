defmodule RetroHexChatWeb.ChatLive.Components.CheatsheetDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.CheatsheetDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert CheatsheetDialog.id() == "cheatsheet-dialog"
  end

  test "renders the bare static bindings panel" do
    html = render_component(CheatsheetDialog, id: CheatsheetDialog.id())

    assert html =~ ~s(data-testid="cheatsheet-dialog")
    refute html =~ "phx-show-modal"
    # The bindings table is computed once at mount.
    assert html =~ "Navigation"
  end
end
