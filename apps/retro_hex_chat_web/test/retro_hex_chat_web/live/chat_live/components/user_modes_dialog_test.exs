defmodule RetroHexChatWeb.ChatLive.Components.UserModesDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.UserModesDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert UserModesDialog.id() == "user-modes-dialog"
  end

  test "renders the panel bare (no modal chrome)" do
    html = render_component(UserModesDialog, id: UserModesDialog.id())

    assert html =~ "data-testid=\"user-modes-panel\""
    refute html =~ "phx-show-modal"
  end

  test "reflects the wallops mode" do
    html = render_component(UserModesDialog, id: UserModesDialog.id(), wallops_enabled: true)

    assert html =~ "Receive wallops (+w)"
    assert html =~ "checked"
  end
end
