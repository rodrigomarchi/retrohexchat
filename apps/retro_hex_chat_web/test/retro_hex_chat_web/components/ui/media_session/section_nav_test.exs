defmodule RetroHexChatWeb.Components.UI.MediaSession.SectionNavTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.MediaSession.SectionNav

  @moduletag :unit

  test "renders scroll cues and preserves item events" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.section_nav
        aria_label="Session sections"
        event="select_section"
        testid="session-nav"
        testid_prefix="session-nav"
      >
        <:item section="call" active={true} label="Call">
          <span>c</span>
        </:item>
        <:item section="stats" active={false} label="Stats">
          <span>s</span>
        </:item>
      </.section_nav>
      """)

    assert html =~ ~s(data-testid="session-nav")
    assert html =~ ~s(data-scroll-cue="horizontal")
    assert html =~ ~s(data-scroll-cue-edge="start")
    assert html =~ ~s(data-scroll-cue-edge="end")
    assert html =~ "media-session-section-nav"
    assert html =~ "media-session-section-nav__item"
    assert html =~ ~s(phx-click="select_section")
    assert html =~ ~s(phx-value-section="call")
    assert html =~ ~s(phx-value-section="stats")
  end
end
