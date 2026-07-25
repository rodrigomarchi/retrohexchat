defmodule RetroHexChatWeb.ChatLive.Components.AwayDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.AwayDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert AwayDialog.id() == "away-dialog"
  end

  test "renders the panel bare (no modal chrome)" do
    html = render_component(AwayDialog, id: AwayDialog.id())

    assert html =~ "data-testid=\"away-panel\""
    refute html =~ "phx-show-modal"
  end

  test "reflects the session's away state and message" do
    html =
      render_component(AwayDialog,
        id: AwayDialog.id(),
        away: true,
        away_message: "Gone fishing"
      )

    assert html =~ "Gone fishing"
    assert html =~ "Away message"
  end
end
