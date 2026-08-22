defmodule RetroHexChatWeb.Components.UI.DesktopLaunchersTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.DesktopLaunchers

  @moduletag :unit

  @group_icon_ids ~w(
    desktop-icon-view
    desktop-icon-tools
    desktop-icon-automation
    desktop-icon-p2p
    desktop-icon-games
    desktop-icon-account
    desktop-icon-admin
    desktop-icon-system
    desktop-icon-language
    desktop-icon-help
  )

  test "desktop icons render the visible app groups in order" do
    html = render_component(&DesktopLaunchers.desktop_launcher_icons/1, screen: :chat)

    assert testids(html, "[data-window-shortcut]") == @group_icon_ids
    assert html =~ ~s(data-window-shortcut="desktop-launcher-games")
    refute html =~ ~s(data-testid="desktop-icon-windows")
    refute html =~ ~s(data-testid="desktop-icon-navigate")
    refute html =~ "desktop-connect-required-dialog"
  end

  test "public desktop icons gate app folders except Language and Help" do
    html = render_component(&DesktopLaunchers.desktop_launcher_icons/1, screen: :landing)
    document = document(html)

    assert testids(html, ".desktop-shortcut") == @group_icon_ids

    assert Floki.attribute(
             document,
             ~s([data-testid="desktop-icon-help"]),
             "data-window-shortcut"
           ) ==
             ["desktop-launcher-help"]

    assert Floki.attribute(
             document,
             ~s([data-testid="desktop-icon-language"]),
             "data-window-shortcut"
           ) ==
             ["desktop-launcher-language"]

    assert Floki.attribute(
             document,
             ~s([data-testid="desktop-icon-help"]),
             "data-desktop-connect-required"
           ) ==
             []

    assert Floki.attribute(
             document,
             ~s([data-testid="desktop-icon-language"]),
             "data-desktop-connect-required"
           ) ==
             []

    assert length(Floki.find(document, "[data-desktop-connect-required]")) ==
             length(@group_icon_ids) - 2

    refute html =~ ~s(data-testid="desktop-icon-windows")
    refute html =~ ~s(data-testid="desktop-icon-navigate")
    refute html =~ "phx-click="
    assert html =~ ~s(data-desktop-connect-required="true")
    assert html =~ "desktop-connect-required-dialog"
  end

  test "chat launcher windows render closed Windows-style app folders" do
    html = render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :chat)

    assert html =~ ~s(data-window-id="desktop-launcher-games")
    assert html =~ ~s(data-window-initial-open="false")
    assert html =~ ~s(data-testid="desktop-launcher-grid-games")
    refute html =~ ~s(data-window-id="desktop-launcher-windows")
    refute html =~ ~s(data-window-id="desktop-launcher-navigate")
    assert enabled?(html, "desktop-launcher-item-retro-games")
    refute enabled?(html, "desktop-launcher-item-open_arcade")
  end

  test "public launcher windows render only the always-available Language and Help folders" do
    html = render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :landing)

    assert html =~ ~s(data-window-id="desktop-launcher-language")
    assert html =~ ~s(data-testid="desktop-launcher-grid-language")
    assert html =~ ~s(data-window-id="desktop-launcher-help")
    assert html =~ ~s(data-testid="desktop-launcher-grid-help")
    refute html =~ ~s(data-window-id="desktop-launcher-games")
    refute html =~ ~s(data-window-id="desktop-launcher-tools")
    refute html =~ ~s(phx-click=)
    assert enabled?(html, "desktop-launcher-item-help_topics")
    assert enabled?(html, "desktop-launcher-item-show_about")
  end

  test "connect keeps Help direct and Language wired to the existing menu" do
    icons_html = render_component(&DesktopLaunchers.desktop_launcher_icons/1, screen: :connect)
    icons = document(icons_html)

    assert Floki.attribute(icons, ~s([data-testid="desktop-icon-help"]), "href") == ["/chat/help"]

    assert Floki.attribute(
             icons,
             ~s([data-testid="desktop-icon-help"]),
             "data-window-shortcut-action"
           ) == ["help_topics"]

    assert Floki.attribute(
             icons,
             ~s([data-testid="desktop-icon-help"]),
             "data-desktop-connect-required"
           ) ==
             []

    assert Floki.attribute(
             icons,
             ~s([data-testid="desktop-icon-language"]),
             "data-desktop-click-target"
           ) == [~s(#menubar [data-testid="language-menu-trigger"])]

    assert Floki.attribute(
             icons,
             ~s([data-testid="desktop-icon-language"]),
             "data-desktop-connect-required"
           ) ==
             []

    windows_html =
      render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :connect)

    taskbar_html =
      render_component(&DesktopLaunchers.desktop_launcher_taskbar_buttons/1, screen: :connect)

    refute windows_html =~ ~s(data-window-id="desktop-launcher-help")
    refute taskbar_html =~ ~s(data-window-taskbar="desktop-launcher-help")
    refute windows_html =~ ~s(data-window-id="desktop-launcher-language")
    refute taskbar_html =~ ~s(data-window-taskbar="desktop-launcher-language")
  end

  test "launcher gates privileged and session-bound items like the Start menu" do
    guest_html = render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :chat)

    refute enabled?(guest_html, "desktop-launcher-item-open_admin_users")
    refute enabled?(guest_html, "desktop-launcher-item-p2p_start_audio")
    assert enabled?(guest_html, "desktop-launcher-item-p2p_how_to_start")

    admin_html =
      render_component(&DesktopLaunchers.desktop_launcher_windows/1,
        screen: :chat,
        is_admin: true,
        p2p_active: true,
        p2p_turn_available: true,
        arcade_available: true
      )

    assert enabled?(admin_html, "desktop-launcher-item-open_admin_users")
    assert enabled?(admin_html, "desktop-launcher-item-p2p_start_audio")
    assert enabled?(admin_html, "desktop-launcher-item-p2p_toggle_privacy")
    assert enabled?(admin_html, "desktop-launcher-item-open_arcade")
    refute enabled?(admin_html, "desktop-launcher-item-p2p_how_to_start")
  end

  test "launcher taskbar buttons target the app-folder windows" do
    html = render_component(&DesktopLaunchers.desktop_launcher_taskbar_buttons/1, screen: :chat)

    assert html =~ ~s(data-window-taskbar="desktop-launcher-tools")
    assert html =~ ~s(data-testid="desktop-launcher-taskbar-tools")
    refute html =~ ~s(data-window-taskbar="desktop-launcher-windows")
    refute html =~ ~s(data-window-taskbar="desktop-launcher-navigate")
  end

  test "public launcher taskbar buttons only target Language and Help" do
    html =
      render_component(&DesktopLaunchers.desktop_launcher_taskbar_buttons/1, screen: :landing)

    assert html =~ ~s(data-window-taskbar="desktop-launcher-language")
    assert html =~ ~s(data-window-taskbar="desktop-launcher-help")
    refute html =~ ~s(data-window-taskbar="desktop-launcher-tools")
  end

  test "connect-required dialog uses the shared Win98 dialog chrome" do
    html = render_component(&DesktopLaunchers.desktop_connect_required_dialog/1, %{})

    assert html =~ ~s(id="desktop-connect-required-dialog")
    assert html =~ "Connect required"
    assert html =~ "This app group needs a chat session."
  end

  defp enabled?(html, testid) do
    case Floki.find(document(html), ~s([data-testid="#{testid}"])) do
      [node | _] ->
        attrs = attrs(node)
        not Map.has_key?(attrs, "disabled") and attrs["aria-disabled"] != "true"

      [] ->
        flunk("missing #{testid}")
    end
  end

  defp testids(html, selector) do
    html
    |> document()
    |> Floki.find(selector)
    |> Enum.map(&attrs(&1)["data-testid"])
  end

  defp document(html), do: Floki.parse_fragment!(html)
  defp attrs({_tag, attrs, _children}), do: Map.new(attrs)
end
