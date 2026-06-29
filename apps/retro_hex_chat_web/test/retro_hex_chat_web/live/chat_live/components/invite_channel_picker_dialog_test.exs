defmodule RetroHexChatWeb.ChatLive.Components.InviteChannelPickerDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.InviteChannelPickerDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert InviteChannelPickerDialog.id() == "invite-channel-picker-dialog"
  end

  test "renders hidden by default" do
    html = render_component(InviteChannelPickerDialog, id: InviteChannelPickerDialog.id())

    assert html =~ "Invite to Channel"
    assert html =~ "hidden"
  end

  test "opens for a target with the available channels" do
    html =
      render_component(InviteChannelPickerDialog,
        id: InviteChannelPickerDialog.id(),
        visible: true,
        channels: ["#general", "#dev"],
        action: {:open, "alice", "#dev"}
      )

    assert html =~ "alice"
    assert html =~ "#general"
    assert html =~ "#dev"
    assert html =~ ~s(data-testid="invite-channel-submit")
  end

  test "shows an error after a failed invite" do
    html =
      render_component(InviteChannelPickerDialog,
        id: InviteChannelPickerDialog.id(),
        visible: true,
        channels: ["#general"],
        action: {:error, "alice", "#general", "You must be a channel operator"}
      )

    assert html =~ ~s(data-testid="invite-channel-error")
    assert html =~ "You must be a channel operator"
  end
end
