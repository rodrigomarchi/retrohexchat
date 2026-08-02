defmodule RetroHexChatWeb.Components.UI.DesktopTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Desktop

  @moduletag :unit

  defp icon, do: %{inner_block: fn _, _ -> "icon" end}

  describe "chrome without a target URL" do
    test "a taskbar button is a button" do
      html = render_component(&taskbar_button/1, window: "chat", label: "Chat", icon: icon())

      assert html =~ ~s(<button)
      assert html =~ ~s(data-window-taskbar="chat")
      refute html =~ "href"
    end

    test "a Start menu item is a button" do
      html = render_component(&start_menu_item/1, label: "Chat", icon: icon())

      assert html =~ ~s(<button)
      refute html =~ "href"
    end

    test "a shortcut is a button" do
      html = render_component(&desktop_shortcut/1, window: "chat", label: "Chat", icon: icon())

      assert html =~ ~s(<button)
      assert html =~ ~s(data-window-shortcut="chat")
      refute html =~ "href"
    end
  end

  # Everything a crawler needs is in the markup before any JavaScript runs, so
  # the desktop chrome must be able to render as ordinary navigation.
  describe "chrome pointing at a URL" do
    test "a taskbar button becomes a link and keeps its window binding" do
      html =
        render_component(&taskbar_button/1,
          window: "button",
          label: "Button",
          href: "/showcase/button",
          icon: icon()
        )

      assert html =~ ~s(<a)
      assert html =~ ~s(href="/showcase/button")
      assert html =~ ~s(data-window-taskbar="button")
      refute html =~ ~s(<button)
    end

    test "a Start menu item becomes a link" do
      html =
        render_component(&start_menu_item/1,
          label: "Button",
          href: "/showcase/button",
          icon: icon()
        )

      assert html =~ ~s(href="/showcase/button")
      refute html =~ ~s(<button)
    end

    test "a shortcut becomes a link" do
      html =
        render_component(&desktop_shortcut/1,
          window: "button",
          label: "Button",
          href: "/showcase/button",
          icon: icon()
        )

      assert html =~ ~s(href="/showcase/button")
      assert html =~ ~s(data-window-shortcut="button")
      refute html =~ ~s(<button)
    end

    test "navigate renders a LiveView-navigable anchor" do
      html =
        render_component(&taskbar_button/1,
          window: "button",
          label: "Button",
          navigate: "/showcase/button",
          icon: icon()
        )

      assert html =~ ~s(href="/showcase/button")
      assert html =~ ~s(data-phx-link="redirect")
    end

    test "a link keeps the same chrome classes as a button" do
      opts = [window: "chat", label: "Chat", icon: icon()]
      button = render_component(&taskbar_button/1, opts)
      link = render_component(&taskbar_button/1, opts ++ [href: "/chat"])

      assert button =~ "desktop-taskbar__button"
      assert link =~ "desktop-taskbar__button"
      assert link =~ "no-underline"
    end
  end
end
