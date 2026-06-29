defmodule RetroHexChatWeb.ChatLive.Components.KickQueueDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.KickQueueDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert KickQueueDialog.id() == "kick-dialog"
  end

  test "renders hidden when the queue is empty" do
    html = render_component(KickQueueDialog, id: KickQueueDialog.id())

    assert html =~ ~s(data-testid="kick-dialog")
    assert html =~ "hidden"
  end

  test "shows the head of the queue after enqueue" do
    html =
      render_component(KickQueueDialog,
        id: KickQueueDialog.id(),
        action: {:enqueue, %{channel: "#elixir", operator: "Op", reason: "spam"}}
      )

    assert html =~ "#elixir"
    assert html =~ ~s(data-testid="kick-dialog-ok")
  end
end
