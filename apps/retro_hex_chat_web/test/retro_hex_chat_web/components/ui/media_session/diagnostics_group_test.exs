defmodule RetroHexChatWeb.Components.UI.MediaSession.DiagnosticsGroupTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.MediaSession.DiagnosticsGroup

  @moduletag :unit

  test "renders a collapsible diagnostics group with visible summary" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.media_session_diagnostics_group
        title="Connection"
        summary="42 ms / 0% loss"
        icon={:icon_status_signal}
        testid="stats-details-connection"
      >
        <dl>
          <dt>Latency</dt>
          <dd>42 ms</dd>
        </dl>
      </.media_session_diagnostics_group>
      """)

    assert html =~ ~s(data-testid="stats-details-connection")
    assert html =~ "Connection"
    assert html =~ "42 ms / 0% loss"
    assert html =~ "Latency"
    refute html =~ ~r/<details[^>]*\sopen(=|\s|>)/
  end

  test "can render open when the caller wants details visible by default" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.media_session_diagnostics_group
        title="Browser connection"
        summary="Good / 42 ms"
        icon={:icon_laptop}
        open={true}
        testid="stats-details-browser"
      >
        <p>Advanced metrics</p>
      </.media_session_diagnostics_group>
      """)

    assert html =~ ~r/<details[^>]*\sopen(=|\s|>)/
    assert html =~ "Browser connection"
    assert html =~ "Advanced metrics"
  end
end
