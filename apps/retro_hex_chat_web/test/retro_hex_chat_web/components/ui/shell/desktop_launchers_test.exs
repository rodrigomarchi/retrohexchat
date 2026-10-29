defmodule RetroHexChatWeb.Components.UI.DesktopLaunchersTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.DesktopLaunchers
  alias RetroHexChatWeb.Components.UI.StartMenuApp
  alias RetroHexChatWeb.GameCatalog

  @moduletag :unit

  # The two game catalogues sit side by side, the Arcade right after Retro
  # Games rather than trailing the column.
  @shortcut_ids ~w(
    desktop-icon-site
    desktop-icon-view
    desktop-icon-tools
    desktop-icon-accessories
    desktop-icon-automation
    desktop-icon-games
    desktop-icon-arcade
    desktop-icon-account
    desktop-icon-language
    desktop-icon-help
  )

  @admin_group_icon_ids ~w(
    desktop-icon-site
    desktop-icon-view
    desktop-icon-tools
    desktop-icon-accessories
    desktop-icon-automation
    desktop-icon-games
    desktop-icon-arcade
    desktop-icon-account
    desktop-icon-admin
    desktop-icon-system
    desktop-icon-language
    desktop-icon-help
  )

  test "desktop icons render the visible app groups in order" do
    html = render_component(&DesktopLaunchers.desktop_launcher_icons/1, screen: :chat)

    assert testids(html, "[data-window-shortcut]") == @shortcut_ids
    assert html =~ ~s(data-window-shortcut="desktop-launcher-games")
    refute html =~ ~s(data-testid="desktop-icon-windows")
    refute html =~ ~s(data-testid="desktop-icon-navigate")
    refute html =~ ~s(data-testid="desktop-icon-admin")
    refute html =~ ~s(data-testid="desktop-icon-system")
    refute html =~ "desktop-connect-required-dialog"
  end

  test "desktop icons render Admin and System only for a chat admin" do
    guest_html = render_component(&DesktopLaunchers.desktop_launcher_icons/1, screen: :chat)

    admin_html =
      render_component(&DesktopLaunchers.desktop_launcher_icons/1, screen: :chat, is_admin: true)

    landing_html =
      render_component(&DesktopLaunchers.desktop_launcher_icons/1,
        screen: :showcase,
        is_admin: true
      )

    refute guest_html =~ ~s(data-testid="desktop-icon-admin")
    refute guest_html =~ ~s(data-testid="desktop-icon-system")

    assert testids(admin_html, "[data-window-shortcut]") == @admin_group_icon_ids

    refute landing_html =~ ~s(data-testid="desktop-icon-admin")
    refute landing_html =~ ~s(data-testid="desktop-icon-system")
  end

  test "public desktop icons gate app folders except Language and Help" do
    html = render_component(&DesktopLaunchers.desktop_launcher_icons/1, screen: :showcase)
    document = document(html)

    assert testids(html, ".desktop-shortcut") == @shortcut_ids

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
             length(@shortcut_ids) - 2

    refute html =~ ~s(data-testid="desktop-icon-windows")
    refute html =~ ~s(data-testid="desktop-icon-navigate")
    refute html =~ ~s(data-testid="desktop-icon-admin")
    refute html =~ ~s(data-testid="desktop-icon-system")
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
    refute html =~ ~s(data-window-id="desktop-launcher-admin")
    refute html =~ ~s(data-window-id="desktop-launcher-system")
    # The Games folder holds a folder per category, and each category's
    # window holds its games.
    assert enabled?(html, "desktop-launcher-item-folder-games-sports")
    assert enabled?(html, "desktop-launcher-item-game-hex_pong")
    assert enabled?(html, "desktop-launcher-item-game-hex_hockey")
    refute html =~ ~s(data-testid="desktop-launcher-item-open_arcade")
  end

  test "the Tools folder lists what the Start menu's Tools submenu lists, in order" do
    launchers = render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :chat)

    menu =
      render_component(&StartMenuApp.start_menu_app/1, screen: :chat, windows: [], full: true)

    folder =
      launchers
      |> Floki.parse_document!()
      |> Floki.find(~s([data-testid="desktop-launcher-window-tools"] [data-testid]))
      |> item_keys("desktop-launcher-item-")

    start =
      menu
      |> Floki.parse_document!()
      |> Floki.find(~s([data-start-submenu-key="tools"] [data-testid]))
      |> item_keys("start-menu-item-")

    assert folder == start
    assert "open_saved_dialog" in folder
    assert "open_events_dialog" in folder
  end

  test "public launcher windows render only the always-available Language and Help folders" do
    html = render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :showcase)

    assert html =~ ~s(data-window-id="desktop-launcher-language")
    assert html =~ ~s(data-testid="desktop-launcher-grid-language")
    assert html =~ ~s(data-window-id="desktop-launcher-help")
    assert html =~ ~s(data-testid="desktop-launcher-grid-help")
    refute html =~ ~s(data-window-id="desktop-launcher-games")
    refute html =~ ~s(data-window-id="desktop-launcher-tools")
    refute html =~ ~s(data-window-id="desktop-launcher-admin")
    refute html =~ ~s(data-window-id="desktop-launcher-system")
    assert enabled?(html, "desktop-launcher-item-help_topics")
    assert enabled?(html, "desktop-launcher-item-show_about")
  end

  test "launcher gates privileged and session-bound items like the Start menu" do
    guest_html = render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :chat)

    refute has_testid?(guest_html, "desktop-launcher-item-open_admin_users")
    refute has_testid?(guest_html, "desktop-launcher-item-open_system_home")

    admin_html =
      render_component(&DesktopLaunchers.desktop_launcher_windows/1,
        screen: :chat,
        is_admin: true
      )

    assert enabled?(admin_html, "desktop-launcher-item-open_admin_users")
    assert enabled?(admin_html, "desktop-launcher-item-open_system_home")
  end

  # Both catalogues are folders of folders: a folder per category, each with a
  # window of its own whose games are cards.
  test "the game catalogues hold a folder per category, each a window of cards" do
    html = render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :chat)
    doc = document(html)

    for {folder, kind} <- [{"games", :multiplayer}, {"arcade", :arcade}],
        group <- GameCatalog.groups(kind) do
      window = "desktop-launcher-#{folder}-#{group.category}"

      assert [item] =
               Floki.find(
                 doc,
                 ~s([data-testid="desktop-launcher-grid-#{folder}"] [data-testid="desktop-launcher-item-folder-#{folder}-#{group.category}"])
               )

      assert Floki.attribute(item, "data-window-open") == [window]
      assert html =~ ~s(data-window-id="#{window}")

      cards =
        Floki.find(doc, ~s([data-testid="desktop-launcher-grid-#{folder}-#{group.category}"] a))

      assert length(cards) == length(group.games)

      for game <- group.games,
          do: assert(Floki.find(cards, ~s(img[src="#{game.screenshot.path}"])) != [])
    end
  end

  # An arcade game's card opens the Arcade on its sheet; the Arcade asks for
  # an account then, so the folders are open to every reader of the chat.
  test "an arcade card opens the Arcade on its game" do
    html = render_component(&DesktopLaunchers.desktop_launcher_windows/1, screen: :chat)

    assert [card] = Floki.find(document(html), ~s([data-testid="arcade-game-doom_shareware"]))
    assert Floki.attribute(card, "href") == ["/?arcade=doom_shareware"]
    assert Floki.attribute(card, "data-phx-link") == ["patch"]

    icons = render_component(&DesktopLaunchers.desktop_launcher_icons/1, screen: :chat)

    assert Floki.attribute(
             document(icons),
             ~s([data-testid="desktop-icon-arcade"]),
             "data-window-shortcut"
           ) ==
             ["desktop-launcher-arcade"]

    visitor =
      render_component(&DesktopLaunchers.desktop_launcher_icons/1, screen: :chat, visitor: true)

    assert enabled?(visitor, "desktop-icon-arcade")
  end

  test "a folder inside a folder has its own taskbar button" do
    html = render_component(&DesktopLaunchers.desktop_launcher_taskbar_buttons/1, screen: :chat)

    assert html =~ ~s(data-window-taskbar="desktop-launcher-arcade-fps")
    assert html =~ ~s(data-testid="desktop-launcher-taskbar-arcade-fps")
    assert html =~ ~s(data-window-taskbar="desktop-launcher-games-cards")
  end

  test "launcher taskbar buttons target the app-folder windows" do
    html = render_component(&DesktopLaunchers.desktop_launcher_taskbar_buttons/1, screen: :chat)

    assert html =~ ~s(data-window-taskbar="desktop-launcher-tools")
    assert html =~ ~s(data-testid="desktop-launcher-taskbar-tools")
    refute html =~ ~s(data-window-taskbar="desktop-launcher-windows")
    refute html =~ ~s(data-window-taskbar="desktop-launcher-navigate")
    refute html =~ ~s(data-window-taskbar="desktop-launcher-admin")
    refute html =~ ~s(data-window-taskbar="desktop-launcher-system")
  end

  test "launcher taskbar buttons include Admin and System for a chat admin" do
    html =
      render_component(&DesktopLaunchers.desktop_launcher_taskbar_buttons/1,
        screen: :chat,
        is_admin: true
      )

    assert html =~ ~s(data-window-taskbar="desktop-launcher-admin")
    assert html =~ ~s(data-window-taskbar="desktop-launcher-system")
  end

  test "public launcher taskbar buttons only target Language and Help" do
    html =
      render_component(&DesktopLaunchers.desktop_launcher_taskbar_buttons/1, screen: :showcase)

    assert html =~ ~s(data-window-taskbar="desktop-launcher-language")
    assert html =~ ~s(data-window-taskbar="desktop-launcher-help")
    refute html =~ ~s(data-window-taskbar="desktop-launcher-tools")
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

  defp has_testid?(html, testid) do
    html
    |> document()
    |> Floki.find(~s([data-testid="#{testid}"]))
    |> Enum.any?()
  end

  defp document(html), do: Floki.parse_fragment!(html)
  defp attrs({_tag, attrs, _children}), do: Map.new(attrs)

  defp item_keys(nodes, prefix) do
    for node <- nodes,
        [testid] = Floki.attribute(node, "data-testid"),
        String.starts_with?(testid, prefix),
        do: String.replace_prefix(testid, prefix, "")
  end
end
