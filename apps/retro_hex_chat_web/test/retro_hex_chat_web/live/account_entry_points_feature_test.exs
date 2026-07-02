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

    test "toolbar actions open Account window entry tabs", %{conn: conn} do
      view = connect_user(conn, "Acct#{uid()}")

      refute has_element?(view, ~s([data-testid="account-window"]))

      render_click(view, "toolbar_action", %{"action" => "open_account_register"})

      assert_push_event(view, "window_command", %{action: "open", id: "account"})
      assert has_element?(view, ~s([data-testid="account-window"]))
      assert render(view) =~ "Register/Login"

      render_click(view, "toolbar_action", %{"action" => "open_account_profile"})
      assert render(view) =~ "Bio (about me)"

      render_click(view, "toolbar_action", %{"action" => "open_account_presence"})
      assert render(view) =~ "Away message"
    end
  end

  describe "account dialog command mapping" do
    test "registered nick shows identify-only auth and keeps bad password errors inline", %{
      conn: conn
    } do
      nick = "Ident#{uid()}"
      assert {:ok, _message} = NickServ.register(nick, "correct123")
      NickServ.remove_identified(nick)
      refute NickServ.identified?(nick)

      view = connect_user(conn, nick)

      render_click(view, "toolbar_action", %{"action" => "open_account_identify"})
      html = render(view)

      assert html =~ ~s(data-testid="account-identify-only")
      assert html =~ ~s(data-testid="account-drop-registration")
      refute html =~ "Register this nickname"

      render_submit(view, "account_register_submit", %{
        "mode" => "identify",
        "password" => "wrong-password"
      })

      html = render(view)
      assert html =~ ~s(data-testid="account-error")
      assert html =~ "[NickServ] Invalid password"
    end

    test "profile tab validates nickname inline before opening nick change flow", %{conn: conn} do
      view = connect_user(conn, "Nick#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_account_profile"})

      render_submit(view, "account_change_nick_submit", %{"nickname" => "bad nick"})
      html = render(view)

      assert html =~ ~s(data-testid="account-nick-error")
      assert html =~ "Nickname cannot contain spaces"
      refute html =~ "bad nick"

      new_nick = "New#{uid()}"
      render_submit(view, "account_change_nick_submit", %{"nickname" => new_nick})
      html = render(view)

      assert html =~ ~s(data-testid="nick-change-dialog")
      assert html =~ new_nick
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
