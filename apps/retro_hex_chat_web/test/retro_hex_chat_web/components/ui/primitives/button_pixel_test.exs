defmodule RetroHexChatWeb.Components.UI.ButtonPixelTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Button

  @moduletag :unit

  test "pixel is the space's wooden button, its look all in CSS" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.button variant="pixel" size="sm"><:icon>i</:icon>Say</.button>
      """)

    assert html =~ "space-pixel-button"
    refute html =~ "space-pixel-button--secondary"
    refute html =~ "shadow-retro"
  end

  test "pixel-secondary is its parchment sibling" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.button variant="pixel-secondary"><:icon>i</:icon>No</.button>
      """)

    assert html =~ "space-pixel-button space-pixel-button--secondary"
    refute html =~ "shadow-retro"
  end
end
