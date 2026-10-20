defmodule RetroHexChatWeb.ChatLive.Components.UserModesDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.UserModesDialog

  @moduletag :unit

  test "reflects the wallops mode" do
    html = render_component(UserModesDialog, id: UserModesDialog.id(), wallops_enabled: true)

    assert html =~ "Receive wallops (+w)"
    assert html =~ "checked"
  end
end
