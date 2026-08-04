defmodule RetroHexChatWeb.BotManagementEntryPointsFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Channels.{Registry, Supervisor}

  alias RetroHexChatWeb.Components.UI.{
    BotManagementDialog,
    MenuBarApp,
    ToolbarApp
  }

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "bot management entry points" do
    test "Tools menu and Options dropdown expose Bot Management only to admins" do
      admin_menu_html =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          is_admin: true,
          on_action: "toolbar_action"
        )

      user_menu_html =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          is_admin: false,
          on_action: "toolbar_action"
        )

      admin_toolbar_html =
        render_component(&ToolbarApp.toolbar_app/1,
          connected: true,
          is_admin: true,
          on_action: "toolbar_action"
        )

      user_toolbar_html =
        render_component(&ToolbarApp.toolbar_app/1,
          connected: true,
          is_admin: false,
          on_action: "toolbar_action"
        )

      assert admin_menu_html =~ ~s(data-testid="context-menu-item-open_bot_dialog")
      assert admin_toolbar_html =~ ~s(data-testid="context-menu-item-open_bot_dialog")
      assert admin_menu_html =~ "Bot Management"
      assert admin_toolbar_html =~ "Bot Management"

      refute user_menu_html =~ ~s(data-testid="context-menu-item-open_bot_dialog")
      refute user_toolbar_html =~ ~s(data-testid="context-menu-item-open_bot_dialog")
    end

    test "toolbar action opens the Bot Management window for an identified admin", %{conn: conn} do
      view = connect_admin(conn)

      refute has_element?(view, ~s([data-testid="bot-management-window"]))

      render_click(view, "toolbar_action", %{"action" => "open_bot_dialog"})

      assert has_element?(view, ~s([data-testid="bot-management-window"]))
      assert has_element?(view, "#bot-management-dialog-content")
    end

    test "a non-admin cannot open Bot Management, and a forged window_open renders nothing",
         %{conn: conn} do
      view = connect_user(conn, "Rando#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_bot_dialog"})
      refute has_element?(view, ~s([data-testid="bot-management-window"]))
      assert render(view) =~ "restricted to server administrators"

      render_hook(view, "window_open", %{"id" => "bot-management-dialog"})
      refute has_element?(view, ~s([data-testid="bot-management-window"]))
    end
  end

  # The window is hidden from non-admins, but a LiveView event does not come from
  # the window — it comes from the socket, and this hook is attached for every
  # session. These assert on the database, which is the only place the damage
  # would be real.
  describe "bot management events are refused to non-admins" do
    test "a non-admin cannot destroy a bot", %{conn: conn} do
      bot_name = "Keep#{uid()}"
      {:ok, _bot} = Queries.create_bot(%{name: bot_name, nickname: bot_name, created_by: "admin"})

      view = connect_user(conn, "Rando#{uid()}")
      render_click(view, "bot_delete", %{"name" => bot_name})

      assert Queries.get_bot_by_name(bot_name)
      assert render(view) =~ "restricted to server administrators"
    end

    test "a non-admin cannot create a bot", %{conn: conn} do
      bot_name = "Forged#{uid()}"

      view = connect_user(conn, "Rando#{uid()}")

      render_click(view, "create_bot", %{
        "name" => bot_name,
        "nickname" => bot_name,
        "description" => "",
        "prefix" => "!",
        "cooldown" => "3"
      })

      refute Queries.get_bot_by_name(bot_name)
      assert render(view) =~ "restricted to server administrators"
    end

    test "a non-admin cannot change an existing bot", %{conn: conn} do
      bot_name = "Intact#{uid()}"

      {:ok, bot} =
        Queries.create_bot(%{
          name: bot_name,
          nickname: bot_name,
          created_by: "admin",
          capabilities: %{"mention" => %{"enabled" => true}}
        })

      view = connect_user(conn, "Rando#{uid()}")

      render_click(view, "bot_toggle_enabled", %{"name" => bot_name})
      render_click(view, "bot_add_channel", %{"channel" => "#lobby", "bot_name" => bot_name})

      render_click(view, "bot_add_command", %{
        "bot_name" => bot_name,
        "trigger" => "pwned",
        "response" => "hello",
        "description" => ""
      })

      render_click(view, "bot_toggle_capability", %{
        "capability" => "mention",
        "bot_name" => bot_name
      })

      render_click(view, "bot_rss_add_feed", %{
        "bot_name" => bot_name,
        "url" => "https://example.com/feed.xml",
        "channel" => "#lobby"
      })

      unchanged = Queries.get_bot_by_name(bot_name)

      assert unchanged.enabled
      assert unchanged.capabilities == bot.capabilities
      assert Queries.list_channel_configs(bot.id) == []
      assert Queries.list_custom_commands(bot.id) == []
    end
  end

  describe "general tab enablement controls" do
    test "selected bot renders an admin-only enable/disable button" do
      bot = bot_struct(name: "ToggleBot", enabled: true)

      admin_html =
        render_component(&BotManagementDialog.bot_management_dialog/1,
          id: "bot-management-dialog",
          show: true,
          bots: [bot],
          selected: bot,
          is_admin: true,
          on_close: "close_bot_dialog"
        )

      user_html =
        render_component(&BotManagementDialog.bot_management_dialog/1,
          id: "bot-management-dialog",
          show: true,
          bots: [bot],
          selected: bot,
          is_admin: false,
          on_close: "close_bot_dialog"
        )

      assert admin_html =~ ~s(data-testid="bot-toggle-enabled-ToggleBot")
      assert admin_html =~ ~s(phx-click="bot_toggle_enabled")
      assert admin_html =~ ~s(phx-value-name="ToggleBot")
      assert admin_html =~ "Disable"

      refute user_html =~ ~s(data-testid="bot-toggle-enabled-ToggleBot")
    end

    test "clicking the enable/disable button toggles the selected bot", %{conn: conn} do
      bot_name = "Bot#{uid()}"
      {:ok, bot} = Queries.create_bot(%{name: bot_name, nickname: bot_name, created_by: "admin"})

      view = connect_admin(conn)
      render_click(view, "toolbar_action", %{"action" => "open_bot_dialog"})
      render_click(view, "bot_select", %{"name" => bot.name})

      view
      |> element(~s([data-testid="bot-toggle-enabled-#{bot.name}"]))
      |> render_click()

      assert Queries.get_bot_by_name(bot.name).enabled == false
      html = render(view)
      assert html =~ "Disabled"
      assert html =~ "Enable"
    end
  end

  defp connect_admin(conn) do
    {:ok, view, _html} = live(chat_conn(conn, "TestAdmin", pre_identified: true), "/chat")
    view
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp bot_struct(attrs) do
    defaults = %{
      name: "TestBot",
      nickname: "TestBot",
      command_prefix: "!",
      enabled: true,
      capabilities: %{}
    }

    Map.merge(defaults, Map.new(attrs))
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
