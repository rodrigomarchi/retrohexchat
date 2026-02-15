defmodule RetroHexChatWeb.Components.ConnectionBannerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.ConnectionBanner

  describe "connection_banner/1" do
    test "renders container with hook attachment" do
      html = render_component(&ConnectionBanner.connection_banner/1, %{})
      assert html =~ "phx-hook=\"ConnectionBannerHook\""
    end

    test "renders with connection-banner class" do
      html = render_component(&ConnectionBanner.connection_banner/1, %{})
      assert html =~ "connection-banner"
    end

    test "renders with unique id" do
      html = render_component(&ConnectionBanner.connection_banner/1, %{})
      assert html =~ "id=\"connection-banner\""
    end

    test "renders with data-testid" do
      html = render_component(&ConnectionBanner.connection_banner/1, %{})
      assert html =~ "data-testid=\"connection-banner\""
    end
  end
end
