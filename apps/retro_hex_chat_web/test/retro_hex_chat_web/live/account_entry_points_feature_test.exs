defmodule RetroHexChatWeb.AccountEntryPointsFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Services.NickServ

  alias RetroHexChatWeb.Components.UI.{
    MenuBarApp,
    StatusBarApp
  }

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "account entry points" do
    test "File menu exposes the Account group actions" do
      menu_html =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          on_action: "toolbar_action"
        )

      assert menu_html =~ "Account"
      assert menu_html =~ ~s(data-testid="context-menu-item-open_account_register")
      assert menu_html =~ ~s(data-testid="context-menu-item-open_account_identify")
      assert menu_html =~ ~s(data-testid="context-menu-item-open_account_profile")
      assert menu_html =~ ~s(data-testid="context-menu-item-open_account_presence")
      assert menu_html =~ ~s(data-testid="context-menu-item-account_info")
      assert menu_html =~ "Register Nickname"
      assert menu_html =~ "Identify"
      assert menu_html =~ "Change Nickname"
      assert menu_html =~ "Edit Profile"
      assert menu_html =~ "Set Away"
      assert menu_html =~ "Account Info"
    end

    test "status bar component renders account state and quick away action" do
      html =
        render_component(&StatusBarApp.status_bar_app/1,
          nickname: "Alice",
          account_state: :guest,
          away: false,
          channel: "#lobby",
          on_account_click: "open_account_dialog",
          on_away_toggle: "toggle_account_away"
        )

      assert html =~ ~s(data-testid="status-bar-account-widget")
      assert html =~ ~s(data-testid="status-bar-away-toggle")
      assert html =~ "Alice · Guest"
      assert html =~ ~s(title="Set Away")
    end

    test "toolbar actions open Account dialog entry tabs", %{conn: conn} do
      view = connect_user(conn, "Acct#{uid()}")

      refute has_element?(view, "#account-dialog-show-trigger")

      render_click(view, "toolbar_action", %{"action" => "open_account_register"})

      assert has_element?(view, "#account-dialog-show-trigger")
      assert render(view) =~ "Register/Login"

      render_click(view, "toolbar_action", %{"action" => "open_account_profile"})
      assert render(view) =~ "Bio (about me)"

      render_click(view, "toolbar_action", %{"action" => "open_account_presence"})
      assert render(view) =~ "Away message"
    end

    test "status bar account widget opens Account dialog and quick away toggle flips state",
         %{conn: conn} do
      view = connect_user(conn, "Away#{uid()}")

      view
      |> element(~s([data-testid="status-bar-account-widget"]))
      |> render_click()

      assert has_element?(view, "#account-dialog-show-trigger")

      view
      |> element(~s([data-testid="status-bar-away-toggle"]))
      |> render_click()

      assert render(view) =~ "Away"
      assert render(view) =~ "You are now away: Away"

      view
      |> element(~s([data-testid="status-bar-away-toggle"]))
      |> render_click()

      assert render(view) =~ "Guest"
      assert render(view) =~ "You are no longer away"
    end
  end

  describe "account dialog command mapping" do
    test "register form runs NickServ registration for the current nick", %{conn: conn} do
      nick = "Reg#{uid()}"
      view = connect_user(conn, nick)

      render_click(view, "toolbar_action", %{"action" => "open_account_register"})

      render_submit(view, "account_register_submit", %{
        "mode" => "register",
        "password" => "secret123",
        "confirm" => "secret123"
      })

      assert NickServ.registered?(nick)
      assert render(view) =~ "#{nick} · Identified"
      assert render(view) =~ "[NickServ] Nickname #{nick} registered successfully"
    end

    test "profile, presence, and user mode forms dispatch their commands", %{conn: conn} do
      view = connect_user(conn, "Prof#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_account_profile"})

      render_submit(view, "account_profile_submit", %{
        "bio" => "Elixir enthusiast from Brazil"
      })

      assert render(view) =~ "* Bio set: Elixir enthusiast from Brazil"

      render_submit(view, "account_presence_submit", %{"away_message" => "Gone to lunch"})
      assert render(view) =~ "You are now away: Gone to lunch"

      render_submit(view, "account_user_modes_submit", %{"wallops" => "true"})
      assert render(view) =~ "User mode +w enabled."
    end
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
