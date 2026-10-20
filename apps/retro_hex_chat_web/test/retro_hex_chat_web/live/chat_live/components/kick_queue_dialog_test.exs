defmodule RetroHexChatWeb.ChatLive.Components.KickQueueDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.KickQueueDialog

  @moduletag :unit

  test "shows the head of the queue after enqueue" do
    html =
      render_component(KickQueueDialog,
        id: KickQueueDialog.id(),
        action: {:enqueue, %{channel: "#elixir", operator: "Op", reason: "spam"}}
      )

    assert html =~ "#elixir"
    assert html =~ "Op"
    assert html =~ "spam"
    assert html =~ "The channel tab was closed"
    assert html =~ "kick_dialog_dismiss"
    assert html =~ ~s(data-testid="kick-dialog-ok")
  end
end
