defmodule RetroHexChatWeb.Components.ToolbarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Toolbar

  describe "toolbar/1" do
    test "shows Disconnect when connected" do
      html = render_component(&Toolbar.toolbar/1, connected: true)
      assert html =~ ~s(data-testid="toolbar-disconnect")
      refute html =~ ~s(data-testid="toolbar-connect")
    end

    test "shows Connect when not connected" do
      html = render_component(&Toolbar.toolbar/1, connected: false)
      assert html =~ ~s(data-testid="toolbar-connect")
      refute html =~ ~s(data-testid="toolbar-disconnect")
    end

    test "always shows Channel List" do
      html = render_component(&Toolbar.toolbar/1, connected: true)
      assert html =~ ~s(data-testid="toolbar-channel-list")
    end
  end
end
