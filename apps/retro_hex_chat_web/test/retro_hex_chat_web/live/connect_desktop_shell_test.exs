defmodule RetroHexChatWeb.ConnectDesktopShellTest do
  @moduledoc """
  The connect page renders as a Win98 desktop: the sign-in flow lives in one
  pinned, centered logon window over a taskbar with a Start menu and a tray
  clock, with a pre-auth status bar in the header.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  describe "desktop shell" do
    test "renders a clean-slate desktop (no layout persistence)", %{conn: conn} do
      {:ok, view, html} = live(conn, "/connect")

      assert has_element?(view, ~s(#connect-desktop[data-persist="false"]))
      # Header chrome: disconnected menu bar + pre-auth status bar.
      assert has_element?(view, ~s(#menubar))
      assert html =~ ~s(data-testid="connect-status-bar")
    end

    test "the mobile rail offers only what works signed out", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      assert has_element?(view, ~s(#menubar [data-testid="app-mobile-menu-rail-language"]))
      assert has_element?(view, ~s(#menubar [data-testid="app-mobile-menu-rail-help"]))
      refute has_element?(view, ~s(#menubar [data-testid="app-mobile-menu-rail-file"]))
      refute has_element?(view, ~s(#menubar [data-testid="app-mobile-menu-rail-tools"]))
    end

    test "the connect window is a pinned, centered, fixed-size logon dialog", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      assert has_element?(
               view,
               ~s(#connect-desktop [data-window-id="connect"][data-window-pinned="true"]) <>
                 ~s([data-window-default-centered="true"][data-window-default-maximized="false"])
             )

      # Pinned: no close control; still minimizable from the title bar.
      refute has_element?(view, ~s([data-window-id="connect"] [data-window-control="close"]))
      assert has_element?(view, ~s([data-window-id="connect"] [data-window-control="minimize"]))
      # Fixed size: no resize handles.
      refute has_element?(view, ~s([data-window-id="connect"] [data-window-resize]))
    end

    test "the taskbar has a connect window button and a tray clock", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      assert has_element?(view, ~s(#connect-desktop [data-window-taskbar="connect"]))
      assert has_element?(view, ~s(#connect-tray-clock[phx-hook="ClockHook"]))
      # The tray owns the clock — the status bar does not show one.
      refute has_element?(view, "#connect-status-clock")
    end

    test "the sign-in form stays in the window body and language lives in the menu bar", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/connect")

      assert has_element?(view, ~s([data-window-id="connect"] form[phx-submit="connect"]))
      refute has_element?(view, ~s([data-window-id="connect"] [data-testid="locale-switcher"]))
      assert has_element?(view, ~s(#menubar [data-testid="language-menu-item-pt_BR"]))

      assert has_element?(
               view,
               ~s(#menubar [data-testid="language-menu-item-pt_BR"] a[href^="/locale/pt_BR"])
             )
    end

    test "the sign-in flow works inside the desktop shell", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      view
      |> element(~s(form[phx-submit="connect"]))
      |> render_submit(%{"nickname" => "Conn#{uid()}"})

      # A fresh nickname moves to the register step, still inside the window.
      assert has_element?(view, ~s([data-window-id="connect"] form[phx-submit="register"]))
      # The status bar tracks the step.
      assert render(element(view, ~s([data-testid="connect-status-bar"]))) =~ "Registration"
    end
  end

  describe "start menu" do
    test "carries the whole app menu, with what Connect can reach live", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      assert has_element?(view, ~s(#connect-desktop [data-window-start]))
      assert has_element?(view, ~s(#connect-start-menu[data-window-start-menu]))

      # Live here: the Connect window, help and about.
      assert has_element?(view, ~s(#connect-start-menu [data-window-open="connect"]))

      assert has_element?(
               view,
               ~s(#connect-start-menu [data-testid="start-menu-item-help_topics"])
             )

      assert has_element?(
               view,
               ~s|#connect-start-menu [data-testid="start-menu-item-show_about"]:not([disabled])|
             )

      # Present but out of reach without a session — the menu names the whole app
      # from every screen rather than becoming a different menu on each one.
      assert has_element?(
               view,
               ~s(#connect-start-menu [data-testid="start-menu-item-address-book"][disabled])
             )

      assert has_element?(
               view,
               ~s(#connect-start-menu [data-testid="start-menu-item-open_admin_users"][disabled])
             )

      assert has_element?(
               view,
               ~s(#connect-start-menu [data-testid="start-menu-item-disconnect"][disabled])
             )
    end

    test "Help Topics navigates to the help viewer", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      view
      |> element(~s(#connect-start-menu [data-testid="start-menu-item-help_topics"]))
      |> render_click()

      assert_redirect(view, "/chat/help")
    end
  end

  describe "menu bar actions" do
    test "Help > Help Topics navigates to the help viewer", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      render_click(view, "menu_action", %{"action" => "help_topics"})

      assert_redirect(view, "/chat/help")
    end

    test "unhandled menu actions are no-ops", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/connect")

      render_click(view, "menu_action", %{"action" => "show_motd"})

      assert has_element?(view, ~s([data-window-id="connect"] form[phx-submit="connect"]))
    end
  end
end
