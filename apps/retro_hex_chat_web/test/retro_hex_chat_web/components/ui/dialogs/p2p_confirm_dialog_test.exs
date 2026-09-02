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
          peer: "trinity",
          on_confirm: "p2p_confirm",
          on_cancel: "p2p_cancel"
        ],
        assigns
      )
    )
  end

  test "the dialog explains all active P2P surfaces that will stop" do
    html = render_dialog([])

    assert html =~ ~s(data-testid="p2p-confirm")
    assert html =~ "End P2P Session"
    assert html =~ "Any call, game or file transfer in progress will stop"
    assert html =~ "Audio/video tracks stop"
    assert html =~ "File transfers stop"
    assert html =~ "P2P games close"
    assert html =~ ~s(data-testid="p2p-confirm-confirm")
    assert html =~ ~s(data-testid="p2p-confirm-cancel")
  end

  # Two modes left with the chat's single P2P window: `:close` warned that the
  # window's X disconnected the session, and `:switch` asked whether to end one
  # session to accept another. The window is pinned and has no X, and a person
  # can hold several sessions at once, so neither question exists.
  test "there is no mode that asks about closing a window or swapping a session" do
    html = render_dialog([])

    refute html =~ "Close P2P Session?"
    refute html =~ "Switch P2P Session"
    refute html =~ "Minimize to keep it running"
    refute html =~ "Only one P2P session can be active"
  end
end
