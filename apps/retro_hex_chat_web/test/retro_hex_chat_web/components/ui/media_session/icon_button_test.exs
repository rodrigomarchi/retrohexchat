defmodule RetroHexChatWeb.Components.UI.MediaSession.IconButtonTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.MediaSession.Dock
  import RetroHexChatWeb.Components.UI.MediaSession.IconButton

  @moduletag :unit

  test "raised is the default look and carries the bevel" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.media_session_icon_button label="Mute">i</.media_session_icon_button>
      """)

    assert html =~ "shadow-retro-raised"
    refute html =~ "media-dock-button"
  end

  test "flat has no chrome at rest and rises under the pointer" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.media_session_icon_button label="Layout" variant="flat">i</.media_session_icon_button>
      """)

    assert html =~ "bg-transparent"
    assert html =~ "hover:shadow-retro-raised"
  end

  test "dock buttons take the dock chrome, the off state and a visible caption" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.media_session_dock aria_label="Call controls" testid="dock">
        <.media_session_icon_button label="Microphone" variant="dock" active pressed={false}>
          i
        </.media_session_icon_button>
        <.media_session_dock_separator />
        <.media_session_icon_button label="Leave call" variant="dock" tone="danger" caption="Leave">
          i
        </.media_session_icon_button>
      </.media_session_dock>
      """)

    assert html =~ ~s(role="toolbar")
    assert html =~ ~s(aria-label="Call controls")
    assert html =~ ~s(class="media-dock-button media-dock-button--active")
    assert html =~ ~s(aria-pressed="false")
    assert html =~ "media-dock__separator"
    assert html =~ "media-dock-button--captioned media-dock-button--danger"
    assert html =~ ~s(<span class="media-session-icon-button__caption">Leave</span>)
    assert html =~ ~s(aria-label="Leave call")
  end

  test "a compact dock is marked for mini windows" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.media_session_dock aria_label="Call controls" compact>x</.media_session_dock>
      """)

    assert html =~ "media-dock media-dock--compact"
  end
end
