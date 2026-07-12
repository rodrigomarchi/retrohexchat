defmodule RetroHexChatWeb.Components.UI.P2PConfirmDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.P2PConfirmDialog

  @moduletag :unit

  defp render_dialog(assigns) do
    render_component(
      &p2p_confirm_dialog/1,
      Keyword.merge(
        [
          id: "p2p-confirm",
          show: true,
          mode: :end,
          peer: "trinity",
          new_peer: "morpheus",
          on_confirm: "p2p_confirm",
          on_cancel: "p2p_cancel"
        ],
        assigns
      )
    )
  end

  test "end mode explains all active P2P surfaces that will stop" do
    html = render_dialog(mode: :end)

    assert html =~ ~s(data-testid="p2p-confirm-dialog")
    assert html =~ "End P2P Session"
    assert html =~ "Any call, game or file transfer in progress will stop"
    assert html =~ "Audio/video tracks stop"
    assert html =~ "File transfers stop"
    assert html =~ "P2P games close"
    assert html =~ ~s(data-testid="p2p-confirm-dialog-confirm")
    assert html =~ ~s(data-testid="p2p-confirm-dialog-cancel")
  end

  test "close mode teaches that minimizing keeps the session running" do
    html = render_dialog(mode: :close)

    assert html =~ "Close P2P Session?"
    assert html =~ "Closing this window disconnects the whole P2P session"
    assert html =~ "Minimize to keep it running"
    assert html =~ "Only one P2P session can be active"
  end

  test "switch mode describes the one-session replacement flow" do
    html = render_dialog(mode: :switch)

    assert html =~ "Switch P2P Session"
    assert html =~ "End the current P2P session with trinity and start one with morpheus"
    assert html =~ "Current P2P session closes first"
    assert html =~ "New invite starts after confirmation"
    assert html =~ "Privacy and relay settings carry over"
  end
end
