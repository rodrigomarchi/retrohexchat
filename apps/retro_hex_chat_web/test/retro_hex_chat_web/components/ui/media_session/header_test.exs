defmodule RetroHexChatWeb.Components.UI.MediaSession.HeaderTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.MediaSession.Header

  @moduletag :unit

  test "keeps title content flexible beside action buttons" do
    assigns = %{title: "Direct call with peermaxxx999999"}

    html =
      rendered_to_string(~H"""
      <.media_session_header
        title={@title}
        actions_label="Window controls"
        testid="media-session-header"
      >
        <:icon>
          <span>i</span>
        </:icon>
        <:meta>
          <span>connected</span>
        </:meta>
        <:actions>
          <button type="button">End</button>
        </:actions>
      </.media_session_header>
      """)

    assert html =~ ~s(data-testid="media-session-header")
    assert html =~ "flex min-w-0 flex-1 items-center gap-2"
    assert html =~ "truncate font-bold leading-4"
    assert html =~ "Direct call with peermaxxx999999"
    assert html =~ ~s(role="toolbar")
    assert html =~ ~s(aria-label="Window controls")
  end
end
