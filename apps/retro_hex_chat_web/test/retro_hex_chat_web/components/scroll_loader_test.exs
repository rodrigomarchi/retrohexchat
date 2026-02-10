defmodule RetroHexChatWeb.Components.ScrollLoaderTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.ScrollLoader

  describe "scroll_loader/1" do
    test "does not render when not loading" do
      html = render_component(&ScrollLoader.scroll_loader/1, loading: false)
      refute html =~ "scroll-loader"
    end

    test "renders progress indicator when loading" do
      html = render_component(&ScrollLoader.scroll_loader/1, loading: true)
      assert html =~ "scroll-loader"
      assert html =~ "Loading messages"
      assert html =~ "progressbar"
    end
  end
end
