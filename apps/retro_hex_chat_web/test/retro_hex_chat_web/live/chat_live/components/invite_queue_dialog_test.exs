defmodule RetroHexChatWeb.ChatLive.Components.InviteQueueDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.InviteQueueDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert InviteQueueDialog.id() == "invite-queue-dialog"
  end

  test "renders hidden when the queue is empty" do
    html = render_component(InviteQueueDialog, id: InviteQueueDialog.id(), invites: [])

    assert html =~ ~s(data-testid="invite-dialog")
    assert html =~ "hidden"
  end

  test "renders an invite card per pending invite (passthrough)" do
    html =
      render_component(InviteQueueDialog,
        id: InviteQueueDialog.id(),
        invites: [
          %{channel: "#elixir", inviter: "alice"},
          %{channel: "#dev", inviter: "bob"}
        ]
      )

    assert html =~ ~s(data-testid="invite-card-#elixir")
    assert html =~ ~s(data-testid="invite-join-#elixir")
    assert html =~ ~s(data-testid="invite-ignore-#dev")
    assert html =~ "#elixir"
    assert html =~ "#dev"
    assert html =~ "Invited by alice"
    assert html =~ "Invited by bob"
    assert html =~ "invite_accept"
    assert html =~ "invite_ignore"
  end
end
