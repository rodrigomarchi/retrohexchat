defmodule RetroHexChatWeb.ChatLive.Components.NicklistTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.Nicklist

  @moduletag :unit

  @users [
    %{nickname: "alice", role: :operator, away: false, muted: false},
    %{nickname: "Bob", role: :regular, away: true, muted: false}
  ]

  test "id/0 is stable" do
    assert Nicklist.id() == "nicklist"
  end

  test "dom_id/1 keys rows by the normalized nick" do
    assert Nicklist.dom_id("Bob") == "nick-bob"
    assert Nicklist.dom_id("alice") == "nick-alice"
  end

  test "renders the stream container and the backdrop toggle even when empty" do
    html = render_component(Nicklist, id: Nicklist.id())

    assert html =~ ~s(data-testid="nicklist")
    assert html =~ ~s(id="nicklist-users")
    assert html =~ ~s(phx-update="stream")
    # The mobile backdrop bubbles toggle_nicklist to the parent.
    assert html =~ "toggle_nicklist"
  end

  test "is hidden when not visible and shown when visible" do
    hidden = render_component(Nicklist, id: Nicklist.id(), visible: false)
    assert hidden =~ "md:shrink-0 hidden"

    shown = render_component(Nicklist, id: Nicklist.id(), visible: true)
    refute shown =~ "md:shrink-0 hidden"
  end

  test "a reset action streams one row per user, keyed by nick" do
    html =
      render_component(Nicklist,
        id: Nicklist.id(),
        visible: true,
        nick_color_fn: fn _nick -> nil end,
        action: {:reset, @users}
      )

    assert html =~ ~s(id="nick-alice")
    assert html =~ ~s(id="nick-bob")
    assert html =~ ~s(data-nick="alice")
    assert html =~ ~s(data-nick="Bob")
    assert html =~ ~s(data-testid="nicklist-item-alice")
  end
end
