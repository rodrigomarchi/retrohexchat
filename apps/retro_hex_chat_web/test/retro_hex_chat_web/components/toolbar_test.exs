defmodule RetroHexChatWeb.Components.ToolbarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Toolbar

  describe "toolbar/1" do
    test "shows Disconnect when connected" do
      html = render_component(&Toolbar.toolbar/1, connected: true)
      assert html =~ "Disconnect"
      refute html =~ ~s(phx-click="connect")
    end

    test "shows Connect when not connected" do
      html = render_component(&Toolbar.toolbar/1, connected: false)
      assert html =~ ~s(phx-click="connect")
      refute html =~ "Disconnect"
    end

    test "always shows Channel List" do
      html = render_component(&Toolbar.toolbar/1, connected: true)
      assert html =~ "Channel List"
    end
  end
end
