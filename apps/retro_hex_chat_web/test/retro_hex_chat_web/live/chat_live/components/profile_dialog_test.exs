defmodule RetroHexChatWeb.ChatLive.Components.ProfileDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.ProfileDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert ProfileDialog.id() == "profile-dialog"
  end

  test "renders the panel bare (no modal chrome)" do
    html = render_component(ProfileDialog, id: ProfileDialog.id(), nickname: "Alice")

    assert html =~ "data-testid=\"profile-panel\""
    refute html =~ "phx-show-modal"
  end

  test "seeds the nickname field and counts the bio" do
    html =
      render_component(ProfileDialog,
        id: ProfileDialog.id(),
        nickname: "Alice",
        bio: "hello"
      )

    assert html =~ "Alice"
    assert html =~ "Bio (about me)"
    assert html =~ "5 / 200"
  end
end
