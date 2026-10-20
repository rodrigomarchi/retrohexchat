defmodule RetroHexChatWeb.ChatLive.Components.AwayDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.AwayDialog

  @moduletag :unit

  test "reflects the session's away state and message" do
    html =
      render_component(AwayDialog,
        id: AwayDialog.id(),
        away: true,
        away_message: "Gone fishing"
      )

    assert html =~ "Gone fishing"
  end
end
