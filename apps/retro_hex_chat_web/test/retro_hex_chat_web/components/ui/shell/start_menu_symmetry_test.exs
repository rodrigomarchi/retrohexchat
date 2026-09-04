defmodule RetroHexChatWeb.Components.UI.StartMenuSymmetryTest do
  @moduledoc """
  The Start menu is the same menu on every screen.

  This is the test that keeps it that way. The old menus drifted apart one
  screen at a time — Connect had three entries, the chat had forty-one, and
  nothing failed when they diverged, because nothing compared them. Here they
  are compared: same base entries, same order, everywhere. What a screen is
  allowed to change is which of them are live; the one visibility exception is
  Admin/System, which are present only in the chat for admins.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.StartMenuApp

  @screens [:chat, :connect, :landing, :help, :showcase]

  # One window per screen, so Windows is never the empty case here.
  @windows [%{id: "w", label: "A window", icon_fn: :icon_chat}]

  # Measured off the classes the primitives carry — see the height test.
  @row_px 24
  @separator_px 6
  @menu_chrome_px 8
  @taskbar_px 30

  # The shortest window the non-stacked desktop is expected to serve. Stacking
  # is keyed on width, so nothing else keeps a short window off this menu.
  @min_viewport_px 480

  describe "symmetry" do
    test "every screen renders the identical set of entries, in the identical order" do
      [{_first_screen, reference} | rest] =
        Enum.map(@screens, fn screen -> {screen, entry_ids(screen)} end)

      for {screen, ids} <- rest do
        assert ids == reference,
               """
               #{screen}'s Start menu differs from the chat's.
                 only on #{screen}: #{inspect(ids -- reference)}
                 missing from #{screen}: #{inspect(reference -- ids)}
               """
      end
    end

    test "every screen renders the identical set of groups, in the identical order" do
      [reference | rest] = Enum.map(@screens, &group_ids/1)

      for ids <- rest, do: assert(ids == reference)
    end

    test "only a chat admin gets the privileged Admin and System groups" do
      for screen <- @screens do
        refute has_group?(screen, "start-menu-admin-submenu")
        refute has_group?(screen, "start-menu-system-submenu")
      end

      admin_groups = group_ids(:chat, is_admin: true)

      assert "start-menu-admin-submenu" in admin_groups
      assert "start-menu-system-submenu" in admin_groups

      refute has_group?(:landing, "start-menu-admin-submenu", is_admin: true)
      refute has_group?(:landing, "start-menu-system-submenu", is_admin: true)
    end

    test "the root list stays short enough to fit on screen without scrolling" do
      # The desktop menu cannot scroll: `overflow` would clip the flyouts that
      # escape to the right. Depth is what keeps it on screen, so the root's
      # height is a real constraint — but it is a height, not a row count, and
      # asserting a bare row count only ever gets ratcheted upward.
      #
      # So it is measured instead, from the classes the rows actually carry:
      #
      #   row        `px-2 py-1 text-xs` + `h-4` icon  → 16 + 2×4  = 24px
      #   separator  `h-[2px] my-[2px]`                →  2 + 2×2  =  6px
      #   menu       `p-[3px]` + `mb-[2px]`            →  2×3 + 2  =  8px
      #   taskbar    `p-[2px]` around a start button              ≈ 30px
      #
      # Stacking is keyed on width (768px), never on height, so a wide but short
      # window still gets this menu and is the case to survive.
      html = render_menu(:chat)
      height = root_height_px(html)

      assert height <= @min_viewport_px,
             """
             the Start menu's root is #{height}px tall and would run off a              #{@min_viewport_px}px window.
             Fold a group into another one rather than adding a row —              #{div(@min_viewport_px - height, @row_px)} rows of headroom left.
             """
    end

    test "no group nests another group" do
      # `openStartSubmenu` closes every other `[data-start-submenu]` in the menu,
      # an ancestor included — a nested group would shut its own parent.
      for screen <- @screens do
        panels = Floki.find(document(screen), "[data-start-submenu-panel]")

        for panel <- panels do
          assert Floki.find(panel, "[data-start-submenu]") == [],
                 "#{screen} nests a group inside a group"
        end
      end
    end
  end

  describe "what each screen can reach" do
    test "the chat drives the app; everything else has the app grayed out" do
      assert enabled?(:chat, "start-menu-item-address-book")
      assert enabled?(:chat, "start-menu-item-disconnect")

      for screen <- @screens -- [:chat] do
        refute enabled?(screen, "start-menu-item-address-book"),
               "#{screen} should not offer a live Address Book"

        refute enabled?(screen, "start-menu-item-disconnect"),
               "#{screen} should not offer a live Disconnect"
      end
    end

    test "admin entries need an admin, not just a chat" do
      refute has_entry?(:chat, "start-menu-item-open_admin_users")
      refute has_entry?(:chat, "start-menu-item-open_system_home")

      assert enabled?(:chat, "start-menu-item-open_admin_users", is_admin: true)
      assert enabled?(:chat, "start-menu-item-open_system_home", is_admin: true)

      # An admin on the landing page is still not in the app.
      refute has_entry?(:landing, "start-menu-item-open_admin_users", is_admin: true)
      refute has_entry?(:landing, "start-menu-item-open_system_home", is_admin: true)
    end

    # A P2P session lives at its own address, and anything hanging under this
    # group would act on one from a screen that is not holding it.
    test "no menu entry anywhere reaches inside a P2P session" do
      for screen <- @screens, entry <- ~w(p2p_how_to_start p2p_start_audio p2p_toggle_privacy) do
        refute has_entry?(screen, "start-menu-item-#{entry}")
      end
    end

    test "Retro Games needs the chat desktop" do
      assert enabled?(:chat, "start-menu-item-retro-games")
      refute enabled?(:connect, "start-menu-item-retro-games")
    end

    test "the public pages are reachable from everywhere, including the chat" do
      for screen <- @screens do
        assert enabled?(screen, "start-menu-item-page-home"),
               "#{screen} should link to the landing page"
      end
    end

    test "a screen never links to itself" do
      refute enabled?(:connect, "start-menu-item-open-the-app")
      refute enabled?(:chat, "start-menu-item-open-the-app")

      # The entry leads to a page carrying the sign-in window, so it is also
      # redundant on the public pages — they already have one open. Help and the
      # showcase are the two screens that do not, and it stays live for them.
      refute enabled?(:landing, "start-menu-item-open-the-app")
      assert enabled?(:help, "start-menu-item-open-the-app")
      assert enabled?(:showcase, "start-menu-item-open-the-app")

      refute enabled?(:help, "start-menu-item-documentation")
      assert enabled?(:chat, "start-menu-item-documentation")

      refute enabled?(:showcase, "start-menu-item-design-system")
      assert enabled?(:landing, "start-menu-item-design-system")
    end

    # Every screen mounts something for it: the landing desktop a window, the
    # other four the `about-dialog` modal. There is no screen that cannot say
    # what this program is.
    test "About works from everywhere" do
      for screen <- @screens do
        assert enabled?(screen, "start-menu-item-show_about"),
               "#{screen} should be able to open About"
      end
    end

    test "the arcade needs an identified nick, not just a chat" do
      refute enabled?(:chat, "start-menu-item-open_arcade")
      assert enabled?(:chat, "start-menu-item-open_arcade", arcade_available: true)

      # The capability without the screen is still nothing to act on.
      refute enabled?(:landing, "start-menu-item-open_arcade", arcade_available: true)
    end

    test "the chat window's own menu needs the chat window" do
      for entry <- ~w(clear_window copy_selection toggle_search toggle_nicklist) do
        assert enabled?(:chat, "start-menu-item-#{entry}")

        for screen <- @screens -- [:chat] do
          refute enabled?(screen, "start-menu-item-#{entry}"),
                 "#{screen} has no chat window for #{entry} to act on"
        end
      end
    end

    test "the help viewer's tabs and history need the help viewer" do
      for entry <- ~w(contents index search back forward) do
        assert enabled?(:help, "start-menu-item-help-#{entry}")

        for screen <- @screens -- [:help] do
          refute enabled?(screen, "start-menu-item-help-#{entry}")
        end
      end
    end

    test "every locale is offered from every screen" do
      for screen <- @screens do
        assert enabled?(screen, "start-menu-item-language-pt_BR"),
               "#{screen} should be able to switch language"
      end
    end

    test "the app switches locale through the redirect, the public pages by path" do
      # Same rows, two href shapes — `LanguageMenu` owns both, and getting the
      # wrong one here would drop a signed-in reader back on /connect.
      assert locale_href(:chat, "pt_BR") =~ "/locale/pt_BR?return_to="
      assert locale_href(:connect, "pt_BR") =~ "return_to=%2Fconnect"
      refute locale_href(:landing, "pt_BR") =~ "/locale/"
    end

    test "help search only works where a help viewer is listening" do
      assert enabled?(:help, "start-menu-item-help-search")

      for screen <- @screens -- [:help] do
        refute enabled?(screen, "start-menu-item-help-search")
      end
    end
  end

  describe "disabled rows are inert" do
    test "a disabled row is never a link, whatever the entry would have been" do
      # `disabled` does nothing to an `<a>`. A grayed row that still navigates is
      # worse than no row at all, so the destination has to go with the gray.
      doc = document(:showcase)
      row = Floki.find(doc, ~s([data-testid="start-menu-item-design-system"]))

      assert [{"button", _attrs, _children}] = row
      assert Floki.attribute(row, "disabled") != []
      assert Floki.attribute(row, "href") == []
    end

    test "a disabled row carries no click and no window to open" do
      doc = document(:landing)
      row = Floki.find(doc, ~s([data-testid="start-menu-item-address-book"]))

      assert Floki.attribute(row, "disabled") != []
      assert Floki.attribute(row, "data-window-open") == []
      assert Floki.attribute(row, "phx-click") == []
      assert Floki.attribute(row, "aria-disabled") == ["true"]
    end

    test "a group whose entries are all dead is grayed but still opens" do
      doc = document(:landing)
      trigger = Floki.find(doc, ~s([data-testid="start-menu-tools-submenu"]))

      assert Floki.attribute(trigger, "disabled") == [],
             "a muted group must still open — the gray says 'not here', not 'not real'"

      assert Floki.attribute(trigger, "class")
             |> List.first()
             |> String.contains?("desktop-start-menu__item--muted")
    end
  end

  describe "the Windows group" do
    test "lists the windows of the desktop it is standing on" do
      doc =
        document(:landing,
          windows: [
            %{id: "readme", label: "Readme", icon_fn: :icon_notepad},
            %{id: "stats", label: "Stats", icon_fn: :icon_status_signal}
          ]
        )

      assert Floki.find(doc, ~s([data-testid="start-menu-item-readme"])) != []
      assert Floki.find(doc, ~s([data-testid="start-menu-item-stats"])) != []
    end

    test "says so when a desktop has no windows rather than opening on nothing" do
      doc = document(:landing, windows: [])
      assert Floki.find(doc, ~s([data-testid="start-menu-item-no-windows"])) != []
    end
  end

  # ── Helpers ─────────────────────────────────────────

  defp render_menu(screen, opts \\ []) do
    render_component(
      &StartMenuApp.start_menu_app/1,
      Keyword.merge([screen: screen, windows: @windows], opts)
    )
  end

  defp document(screen, opts \\ []) do
    screen |> render_menu(opts) |> Floki.parse_document!()
  end

  # Every entry's testid, in document order. The Windows group is excluded: it is
  # the one group whose contents are meant to differ per screen.
  defp entry_ids(screen) do
    screen
    |> document()
    |> Floki.find("[data-testid^='start-menu-item-']")
    |> Floki.attribute("data-testid")
    |> Enum.reject(&(&1 in window_group_ids()))
  end

  defp window_group_ids do
    ["start-menu-item-w", "start-menu-item-no-windows"]
  end

  defp group_ids(screen, opts \\ []) do
    screen
    |> document(opts)
    |> Floki.find("[data-start-submenu-trigger]")
    |> Floki.attribute("data-testid")
  end

  # Direct children of the menu that are rows: group triggers plus any loose
  # entry (Disconnect). Rows inside a flyout do not add to the root's height.
  defp root_row_count(html) do
    doc = Floki.parse_document!(html)

    groups = doc |> Floki.find("[data-window-start-menu] > [data-start-submenu]") |> length()
    loose = doc |> Floki.find("[data-window-start-menu] > button") |> length()

    groups + loose
  end

  defp root_separator_count(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("[data-window-start-menu] > div:not([data-start-submenu])")
    |> length()
  end

  # What the root claims above the taskbar, bottom edge of the screen included.
  defp root_height_px(html) do
    root_row_count(html) * @row_px +
      root_separator_count(html) * @separator_px +
      @menu_chrome_px + @taskbar_px
  end

  defp locale_href(screen, code) do
    screen
    |> document()
    |> Floki.find(~s([data-testid="start-menu-item-language-#{code}"]))
    |> Floki.attribute("href")
    |> List.first()
    |> Kernel.||("")
  end

  defp enabled?(screen, testid, opts \\ []) do
    screen
    |> document(opts)
    |> Floki.find(~s([data-testid="#{testid}"]))
    |> case do
      [] -> flunk("#{screen} has no entry #{testid} — symmetry is broken")
      row -> Floki.attribute(row, "disabled") == []
    end
  end

  defp has_entry?(screen, testid, opts \\ []) do
    screen
    |> document(opts)
    |> Floki.find(~s([data-testid="#{testid}"]))
    |> Enum.any?()
  end

  defp has_group?(screen, testid, opts \\ []) do
    screen
    |> document(opts)
    |> Floki.find(~s([data-start-submenu-trigger][data-testid="#{testid}"]))
    |> Enum.any?()
  end
end
