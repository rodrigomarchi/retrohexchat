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
  end

  test "buttons never steal keyboard focus and stay pointer-only" do
    html = render_component(&space_virtual_pad/1, %{})

    # 4 directions + attack, all out of the tab order.
    assert length(String.split(html, ~s(tabindex="-1"))) == 6
    # touch-action: none so a drag on the pad never scrolls the page.
    assert html =~ "touch-none"
  end
end
