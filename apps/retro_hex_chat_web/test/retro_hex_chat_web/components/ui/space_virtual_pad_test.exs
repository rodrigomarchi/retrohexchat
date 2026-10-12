defmodule RetroHexChatWeb.Components.UI.SpaceVirtualPadTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SpaceVirtualPad

  @moduletag :unit

  test "renders the four D-pad directions and the attack button for the pad JS" do
    html = render_component(&space_virtual_pad/1, %{})

    assert html =~ ~s(data-space-pad)
    assert html =~ ~s(data-testid="space-virtual-pad")

    for dir <- ~w(up down left right) do
      assert html =~ ~s(data-space-pad-dir="#{dir}")
    end

    assert html =~ ~s(data-space-pad-action="attack")
    assert html =~ ~s(data-space-pad-action="use")
  end

  test "buttons never steal keyboard focus and stay pointer-only" do
    html = render_component(&space_virtual_pad/1, %{})

    # 4 directions + use + attack, all out of the tab order.
    assert length(String.split(html, ~s(tabindex="-1"))) == 7
    # touch-action: none so a drag on the pad never scrolls the page.
    assert html =~ "touch-none"
  end

  test "is drawn in the space's pixel kit: wooden keys, pixel glyphs, the red attack" do
    html = render_component(&space_virtual_pad/1, %{})

    assert html =~ "space-pad-dpad"
    assert html =~ "space-pad-button--attack"

    for icon <- ~w(pad-up pad-down pad-left pad-right use attack) do
      assert html =~ "space-icon--#{icon}"
    end

    refute html =~ "<svg"
    refute html =~ "bg-black"
  end
end
