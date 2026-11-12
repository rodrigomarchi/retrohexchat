defmodule RetroHexChatWeb.AutopilotMetaTest do
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :unit

  alias RetroHexChatWeb.Layouts

  # A game's seat can be played by its computer player only on a page the e2e
  # server built: any other build — this one, production — never says it may.
  test "a build other than the e2e server's never allows the autopilot", %{conn: conn} do
    refute Layouts.autopilot?()

    for path <- ["/", "/games/hex-invaders"] do
      html = conn |> get(path) |> html_response(200)
      refute html =~ "rhc-autopilot"
      assert html =~ ~s(<meta name="faro-enabled")
    end
  end
end
