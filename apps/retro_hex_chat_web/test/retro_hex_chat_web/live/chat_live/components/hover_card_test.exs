defmodule RetroHexChatWeb.ChatLive.Components.HoverCardTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.HoverCard

  @moduletag :unit

  defp card(nick, extra \\ %{}) do
    Map.merge(
      %{visible: true, nick: nick, x: 10, y: 20, loading: false, data: %{}},
      extra
    )
  end

  test "id/0 is stable" do
    assert HoverCard.id() == "hover-card"
  end

  test "renders nothing visible when hidden (default)" do
    html = render_component(HoverCard, id: HoverCard.id())
    refute html =~ "alice"
  end

  test "a :set action shows the card with the nick and fields" do
    html =
      render_component(HoverCard,
        id: HoverCard.id(),
        action: {:set, card("alice", %{host: "alice@host", registered: true})}
      )

    assert html =~ "alice"
  end

  test "a :dismiss action hides the card" do
    html =
      render_component(HoverCard,
        id: HoverCard.id(),
        action: {:set, card("alice")}
      )

    assert html =~ "alice"

    hidden =
      render_component(HoverCard, id: HoverCard.id(), action: :dismiss)

    refute hidden =~ "alice"
  end

  test "the close button bubbles the parent dismiss event" do
    html =
      render_component(HoverCard,
        id: HoverCard.id(),
        action: {:set, card("alice")}
      )

    assert html =~ "nick_hover_dismiss"
  end
end
