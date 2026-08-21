defmodule RetroHexChatWeb.Components.UI.StartMenuSupersetTest do
  @moduledoc """
  The Start menu offers everything every menu bar offers.

  `StartMenuSymmetryTest` holds the menu identical across screens. This holds it
  complete: an entry in the chat's `MenuBarApp`, the help viewer's `HelpMenuBar`
  or the landing shell's strip exists here too. Without it the menus drift the
  way they already drifted once — the bars grew Edit, View, Language, MOTD and
  the Arcade while the Start menu never heard about any of them.

  It is also the precondition for retiring a menu bar: while this passes,
  removing one takes nothing away.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.Help.HelpMenuBar
  alias RetroHexChatWeb.Components.UI.Landing.LandingShell
  alias RetroHexChatWeb.Components.UI.{LanguageMenu, MenuBarApp, StartMenuApp}

  # Entries the bar reaches by server action and the Start menu reaches by
  # opening the window directly — same window, two routes. The bar has to ask
  # the server because its item carries no window id; the Start menu's does, so
  # it opens client-side.
  @same_window_by_other_name %{
    "toggle_address_book" => "address-book",
    "toggle_notify_list" => "notify-list",
    "toggle_url_catcher" => "url-catcher",
    "toggle_cheatsheet" => "cheatsheet",
    "open_ignore_list_dialog" => "ignore-list",
    "open_highlight_dialog" => "highlight",
    "open_user_lookup" => "user-lookup",
    "open_nick_colors_dialog" => "nick-colors",
    "open_sound_settings_dialog" => "sound-settings",
    "open_flood_protection_dialog" => "flood-protection",
    "open_perform_dialog" => "perform",
    "open_autojoin_dialog" => "autojoin",
    "open_autorespond_dialog" => "auto-respond",
    "open_alias_dialog" => "alias",
    "open_custom_menus_dialog" => "custom-menus",
    "open_timers_dialog" => "timers"
  }

  # Rows the Start menu already carries under a different label, matched by
  # destination rather than by name.
  @same_row_under_another_label %{
    # File ▸ Change Nickname... and File ▸ Edit Profile... are one action.
    "open_profile_dialog" => "open_profile_dialog",
    # The help bar's Home and Navigate ▸ Documentation both go to /chat/help.
    "home" => "documentation",
    # The landing bar says "docs" for the same destination.
    "docs" => "documentation",
    "about" => "show_about"
  }

  test "the chat's menu bar offers nothing the Start menu does not" do
    assert missing(chat_bar_entries(), start_entries(:chat)) == []
  end

  test "the help viewer's menu bar offers nothing the Start menu does not" do
    assert missing(help_bar_entries(), start_entries(:help)) == []
  end

  test "the landing shell's menu bar offers nothing the Start menu does not" do
    assert missing(landing_bar_entries(), start_entries(:landing)) == []
  end

  test "every language the bars offer is offered by the Start menu" do
    # The locale rows are the one set both sides name differently, so they match
    # on the locale code rather than on the whole id.
    bar = scan(language_bar_html(), ~r/data-testid="language-menu-item-([A-Za-z0-9_\-]+)"/)
    start = start_entries(:landing)

    assert bar != MapSet.new(), "the language menu rendered no locales at all"
    assert Enum.reject(bar, &MapSet.member?(start, "language-" <> &1)) == []
  end

  test "the alias tables map only entries the bars actually have" do
    # A stale row would quietly excuse an entry that no longer exists.
    bar =
      chat_bar_entries()
      |> MapSet.union(help_bar_entries())
      |> MapSet.union(landing_bar_entries())

    stale =
      (Map.keys(@same_window_by_other_name) ++ Map.keys(@same_row_under_another_label))
      |> Enum.reject(&MapSet.member?(bar, &1))
      |> Enum.sort()

    assert stale == [], "no menu bar has these any more: #{inspect(stale)}"
  end

  # ── Helpers ─────────────────────────────────────────

  defp missing(bar_entries, start_entries) do
    bar_entries
    |> Enum.reject(&reachable?(&1, start_entries))
    |> Enum.sort()
  end

  # The four ways an entry can be the same entry: same id, the help viewer's
  # rows keeping their `help-` prefix, the landing pages keeping their `page-`
  # one, and the two alias tables above.
  defp reachable?(entry, start_entries) do
    [
      entry,
      "help-" <> entry,
      "page-" <> entry,
      @same_window_by_other_name[entry],
      @same_row_under_another_label[entry]
    ]
    |> Enum.any?(&(&1 && MapSet.member?(start_entries, &1)))
  end

  defp start_entries(screen) do
    render_component(&StartMenuApp.start_menu_app/1, screen: screen, windows: [])
    |> scan(~r/data-testid="start-menu-item-([A-Za-z0-9_\-]+)"/)
  end

  defp chat_bar_entries do
    render_component(&MenuBarApp.menu_bar_app/1,
      connected: true,
      is_admin: true,
      on_action: "toolbar_action"
    )
    |> scan(~r/data-testid="context-menu-item-([A-Za-z0-9_\-]+)"/)
  end

  defp help_bar_entries do
    # The bar's own testid (`help-menu-bar`) matches the item pattern, so it is
    # dropped rather than chased.
    render_component(&HelpMenuBar.help_menu_bar/1, [])
    |> scan(~r/data-testid="help-menu-([A-Za-z0-9_\-]+)"/)
    |> MapSet.delete("bar")
  end

  defp landing_bar_entries do
    # The strip names a page by its atom (`how_it_works`), the Start menu by its
    # path segment (`how-it-works`).
    render_component(&LandingShell.landing_layout/1,
      active_page: :home,
      windows: [],
      inner_block: [%{__slot__: :inner_block, inner_block: fn _args, _assigns -> "" end}]
    )
    |> scan(~r/data-testid="landing-menu-(?:nav-)?([A-Za-z0-9_\-]+)"/)
    |> MapSet.delete("bar")
    |> Enum.map(&String.replace(&1, "_", "-"))
    |> MapSet.new()
  end

  defp language_bar_html do
    render_component(&LanguageMenu.language_menu/1, mode: :public, current_path: "/")
  end

  defp scan(html, pattern) do
    pattern |> Regex.scan(html) |> Enum.map(&List.last/1) |> MapSet.new()
  end
end
