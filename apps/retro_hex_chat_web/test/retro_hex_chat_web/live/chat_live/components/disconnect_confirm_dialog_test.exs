defmodule RetroHexChatWeb.ChatLive.Components.DisconnectConfirmDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.DisconnectConfirmDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert DisconnectConfirmDialog.id() == "disconnect-confirm-dialog"
  end

  test "renders the dialog root hidden by default" do
    html = render_component(DisconnectConfirmDialog, id: DisconnectConfirmDialog.id())

    assert html =~ ~s(data-testid="disconnect-confirm-dialog")
    assert html =~ "hidden"
  end

  test "opens via the :open action and exposes confirm/cancel controls" do
    html =
      render_component(DisconnectConfirmDialog, id: DisconnectConfirmDialog.id(), action: :open)

    assert html =~ "Disconnect from Server"
    assert html =~ ~s(data-testid="disconnect-confirm-dialog-confirm")
    assert html =~ ~s(data-testid="disconnect-confirm-dialog-cancel")
  end
end
