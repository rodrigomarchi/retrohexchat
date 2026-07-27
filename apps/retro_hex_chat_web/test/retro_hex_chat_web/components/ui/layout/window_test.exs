defmodule RetroHexChatWeb.Components.UI.WindowTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Window

  @moduletag :unit

  defp render_title_bar(assigns) do
    render_component(
      &window_title_bar/1,
      Keyword.merge(
        [
          title: "#limeira",
          icon: %{inner_block: fn _, _ -> "icon" end}
        ],
        assigns
      )
    )
  end

  describe "window_title_bar/1 meta slot" do
    test "windows without live status render no meta element" do
      html = render_title_bar([])

      refute html =~ "window-title-meta"
      assert html =~ "#limeira"
    end

    test "the meta element carries the class its contrast rule keys off" do
      # The 16×16 icons are drawn with a fixed navy that matches the title bar
      # gradient. Only the CSS rule bound to this class makes them visible, so
      # losing the class silently makes the status unreadable.
      html = render_title_bar(meta: %{inner_block: fn _, _ -> "Connected" end})

      assert html =~ "window-title-meta"
      assert html =~ "Connected"
    end

    test "meta text is fully opaque white, not a dimmed variant" do
      html = render_title_bar(meta: %{inner_block: fn _, _ -> "Connected" end})

      assert html =~ "text-white"
      refute html =~ "text-white/"
    end

    test "meta is hidden on narrow windows where the title bar has no room" do
      html = render_title_bar(meta: %{inner_block: fn _, _ -> "Connected" end})

      assert html =~ "hidden sm:flex"
    end
  end
end
