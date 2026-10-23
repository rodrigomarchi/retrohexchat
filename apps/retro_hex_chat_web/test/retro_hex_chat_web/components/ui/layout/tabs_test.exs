defmodule RetroHexChatWeb.Components.UI.TabsTest do
  @moduledoc """
  The default tab is drawn active by the server.

  A window opened after the page loaded is built off the document by the
  window manager and put in place afterwards, and the tabs' mount command
  does not reach it: Custom Menus opened from `/popups` showed no tab
  active. The server renders the default tab's state and its panel's
  visibility, so the window is right before any script runs.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Tabs

  @moduletag :unit

  test "the default tab is active and only its panel shows" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.tabs :let={builder} id="t" default="b">
        <.tabs_list>
          <.tabs_trigger builder={builder} value="a"><:icon>a</:icon>A</.tabs_trigger>
          <.tabs_trigger builder={builder} value="b"><:icon>b</:icon>B</.tabs_trigger>
        </.tabs_list>
        <.tabs_content builder={builder} value="a">panel a</.tabs_content>
        <.tabs_content builder={builder} value="b">panel b</.tabs_content>
      </.tabs>
      """)

    [a, b] = Floki.find(Floki.parse_fragment!(html), ".tabs-trigger")
    assert Floki.attribute(a, "data-state") == []
    assert Floki.attribute(b, "data-state") == ["active"]

    [panel_a, panel_b] = Floki.find(Floki.parse_fragment!(html), ".tabs-content")
    assert Floki.attribute(panel_a, "class") |> hd() =~ "hidden"
    refute Floki.attribute(panel_b, "class") |> hd() =~ "hidden"
  end
end
