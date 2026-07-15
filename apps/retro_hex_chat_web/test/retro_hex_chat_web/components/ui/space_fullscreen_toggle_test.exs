defmodule RetroHexChatWeb.Components.UI.SpaceFullscreenToggleTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SpaceFullscreenToggle

  @moduletag :unit

  test "renders the toggle hook target with both state glyphs" do
    html = render_component(&space_fullscreen_toggle/1, %{})

    assert html =~ ~s(data-space-fullscreen-toggle)
    assert html =~ ~s(data-testid="space-fullscreen-toggle")
    # Enter glyph shows by default; exit glyph swaps in via data-fullscreen.
    assert html =~ "group-data-[fullscreen]:hidden"
    assert html =~ "group-data-[fullscreen]:block"
    # Pointer-only, like the virtual pad.
    assert html =~ ~s(tabindex="-1")
  end
end
