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

  describe "the pixel skin" do
    test "is the Virtual Space's frame and leaves the Win98 chrome out" do
      html = render_title_bar(skin: "pixel")

      assert html =~ "window-title-bar--pixel"
      assert html =~ "window-title-bar__title--pixel"
      refute html =~ "from-primary"
      # Its controls are the kit's bare gold glyphs.
      assert html =~ "space-pixel-tool"
      assert html =~ "space-icon--win-close"
      refute html =~ "<svg"
    end

    test "the retro skin is the default and is untouched" do
      html = render_title_bar([])

      assert html =~ "from-primary"
      refute html =~ "--pixel"
    end

    test "a status field takes the parchment strip" do
      html =
        render_component(&window_status_bar_field/1,
          skin: "pixel",
          inner_block: [%{inner_block: fn _, _ -> "2 in the space" end, __slot__: :inner_block}]
        )

      assert html =~ "window-status-field--pixel"
      refute html =~ "shadow-retro-status"
    end
  end
end
