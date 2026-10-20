defmodule RetroHexChatWeb.ChatLive.Components.ProfileDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.ProfileDialog

  @moduletag :unit

  test "seeds the nickname field and counts the bio" do
    html =
      render_component(ProfileDialog,
        id: ProfileDialog.id(),
        nickname: "Alice",
        bio: "hello"
      )

    assert html =~ "Alice"
    assert html =~ ~s(data-testid="profile-bio")
    assert html =~ "5 / 200"
  end
end
