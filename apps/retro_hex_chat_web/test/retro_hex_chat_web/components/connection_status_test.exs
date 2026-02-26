defmodule RetroHexChatWeb.Components.ConnectionStatusTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.ConnectionStatus

  describe "connection_status/1" do
    test "renders container with hook attachment" do
      html = render_component(&ConnectionStatus.connection_status/1, %{})
      assert html =~ "phx-hook=\"ConnectionStatusHook\""
    end

    test "renders with unique id" do
      html = render_component(&ConnectionStatus.connection_status/1, %{})
      assert html =~ "id=\"connection-status\""
    end

    test "renders with data-testid" do
      html = render_component(&ConnectionStatus.connection_status/1, %{})
      assert html =~ "data-testid=\"connection-status\""
    end

    test "renders banner sub-element" do
      html = render_component(&ConnectionStatus.connection_status/1, %{})
      assert html =~ "data-role=\"banner\""
      assert html =~ "data-role=\"banner-text\""
    end

    test "renders overlay sub-element" do
      html = render_component(&ConnectionStatus.connection_status/1, %{})
      assert html =~ "data-role=\"overlay\""
      assert html =~ "data-role=\"overlay-info\""
      assert html =~ "data-role=\"overlay-countdown\""
      assert html =~ "data-role=\"overlay-action\""
    end

    test "renders overlay title bar" do
      html = render_component(&ConnectionStatus.connection_status/1, %{})
      assert html =~ "Connection Lost"
    end

    test "renders banner with connection-banner class" do
      html = render_component(&ConnectionStatus.connection_status/1, %{})
      assert html =~ "class=\"connection-banner\""
    end

    test "renders overlay with reconnect-overlay class" do
      html = render_component(&ConnectionStatus.connection_status/1, %{})
      assert html =~ "class=\"reconnect-overlay\""
    end
  end
end
