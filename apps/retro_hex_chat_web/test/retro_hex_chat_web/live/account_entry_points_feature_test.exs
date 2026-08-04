defmodule RetroHexChatWeb.AccountEntryPointsFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Services.NickServ

  alias RetroHexChatWeb.Components.UI.{
    MenuBarApp,
    StartMenuApp,
    StatusBarApp,
    ToolbarApp
  }

  # window id => the canonical action that opens it
  @account_windows %{
    "account" => "open_account_dialog",
    "profile" => "open_profile_dialog",
    "away" => "open_away_dialog",
    "user-modes" => "open_user_modes_dialog"
  }

  # A surface may reach a window through any of these. The File menu opens
  # Account through the role-specific Register/Identify items rather than a
  # generic one, so a single-action assertion would fail there for the wrong
  # reason.
  @account_window_actions %{
    "account" => ~w(open_account_dialog open_account_register open_account_identify),
    "profile" => ~w(open_profile_dialog),
    "away" => ~w(open_away_dialog),
    "user-modes" => ~w(open_user_modes_dialog)
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
      assert menu_html =~ ~s(data-testid="context-menu-item-open_profile_dialog")
      assert menu_html =~ ~s(data-testid="context-menu-item-open_away_dialog")
      assert menu_html =~ ~s(data-testid="context-menu-item-open_user_modes_dialog")
      assert menu_html =~ ~s(data-testid="context-menu-item-account_info")
      assert menu_html =~ "Register Nickname"
      assert menu_html =~ "Identify"
      assert menu_html =~ "Change Nickname"
      assert menu_html =~ "Edit Profile"
      assert menu_html =~ "Set Away"
      assert menu_html =~ "User Modes"
      assert menu_html =~ "Account Info"
    end

    # The account group is action-driven on all three surfaces — it deliberately
    # avoids the start menu's `data-window-open` items, because opening Account
    # and Profile has server-side work attached (identity sync, bio seeding).
    test "all three navigation surfaces offer every account window" do
      for {surface, html} <- surfaces() do
        for {window, actions} <- @account_window_actions do
          assert Enum.any?(actions, fn action ->
                   html =~ ~s(data-testid="context-menu-item-#{action}") or
                     html =~ ~s(data-testid="start-menu-item-#{action}")
                 end),
                 "#{surface} should offer #{window}"
        end
      end
    end

    # The status bar used to carry an account widget and a one-click away
    # toggle. Both left when the window title bar took over naming who you are;
    # the three navigation surfaces above are the account entry points now.
    test "the status bar no longer duplicates the account state" do
      html = render_component(&StatusBarApp.status_bar_app/1, lag_ms: 42)

      refute html =~ ~s(data-testid="status-bar-account-widget")
      refute html =~ ~s(data-testid="status-bar-away-toggle")
    end

    test "every account window mounts managed and unmounts when closed", %{conn: conn} do
      view = connect_user(conn, "Acct#{uid()}")

      for {window, action} <- @account_windows do
        refute has_element?(view, ~s([data-window-id="#{window}"])),
               "#{window} should not be mounted before opening"

        render_click(view, "toolbar_action", %{"action" => action})

        assert has_element?(view, ~s([data-window-id="#{window}"][data-window-managed="true"])),
               "#{window} should mount as a managed window"

        assert_push_event(view, "window_command", %{action: "open", id: ^window})

        render_hook(view, "window_closed", %{"id" => window})

        refute has_element?(view, ~s([data-window-id="#{window}"])),
               "#{window} should unmount when closed"
      end
    end

    test "each window carries only its own feature", %{conn: conn} do
      view = connect_user(conn, "Split#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_account_register"})
      html = render(view)
      assert html =~ ~s(data-testid="account-panel")
      refute html =~ "Bio (about me)"
      refute html =~ "Away message"
      refute html =~ "Receive wallops"

      render_click(view, "toolbar_action", %{"action" => "open_profile_dialog"})
      assert render(view) =~ "Bio (about me)"

      render_click(view, "toolbar_action", %{"action" => "open_away_dialog"})
      assert render(view) =~ "Away message"

      render_click(view, "toolbar_action", %{"action" => "open_user_modes_dialog"})
      assert render(view) =~ "Receive wallops"
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

    test "profile window validates nickname inline before opening nick change flow", %{conn: conn} do
      view = connect_user(conn, "Nick#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_profile_dialog"})

      render_submit(view, "profile_change_nick_submit", %{"nickname" => "bad nick"})
      html = render(view)

      assert html =~ ~s(data-testid="profile-nick-error")
      assert html =~ "Nickname cannot contain spaces"
      refute html =~ "bad nick"

      new_nick = "New#{uid()}"
      render_submit(view, "profile_change_nick_submit", %{"nickname" => new_nick})
      html = render(view)

      assert html =~ ~s(data-testid="nick-change-dialog")
      assert html =~ new_nick
    end

    test "away window sets and clears the away state", %{conn: conn} do
      view = connect_user(conn, "Away#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_away_dialog"})

      render_submit(view, "away_submit", %{"away" => "true", "away_message" => "Gone fishing"})
      assert session(view).away
      assert session(view).away_message == "Gone fishing"

      render_click(view, "away_clear")
      refute session(view).away
    end

    test "user modes window toggles wallops", %{conn: conn} do
      view = connect_user(conn, "Umode#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_user_modes_dialog"})

      render_submit(view, "user_modes_submit", %{"wallops" => "true"})
      assert Session.has_mode?(session(view), :wallops)

      render_submit(view, "user_modes_submit", %{})
      refute Session.has_mode?(session(view), :wallops)
    end
  end

  defp surfaces do
    [
      {"menu bar",
       render_component(&MenuBarApp.menu_bar_app/1,
         connected: true,
         on_action: "toolbar_action"
       )},
      {"start menu",
       render_component(&StartMenuApp.start_menu_app/1,
         screen: :chat,
         on_action: "toolbar_action"
       )},
      {"toolbar",
       render_component(&ToolbarApp.toolbar_app/1,
         connected: true,
         on_action: "toolbar_action"
       )}
    ]
  end

  defp session(view), do: :sys.get_state(view.pid).socket.assigns.session

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
