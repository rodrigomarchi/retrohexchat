defmodule RetroHexChatWeb.ServerAdministrationFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.Components.UI.MenuBarApp

  setup do
    Application.put_env(:retro_hex_chat, :motd_cache, :unset)

    on_exit(fn ->
      Application.put_env(:retro_hex_chat, :motd_cache, :unset)
    end)

    :ok
  end

  describe "MOTD help entry point" do
    test "Help menu exposes Message of the Day for every connected user" do
      document =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          is_admin: false,
          on_action: "toolbar_action"
        )
        |> Floki.parse_document!()

      help_section =
        document
        |> Floki.find("nav > div")
        |> Enum.at(4)

      assert "show_motd" in menu_actions(help_section)
      assert Floki.raw_html(help_section) =~ "Message of the Day"
    end

    test "toolbar action show_motd renders the current MOTD in Status", %{conn: conn} do
      view = connect_user(conn, "MotdView#{uid()}")
      motd = "motd-menu-marker-#{uid()}"

      Application.put_env(:retro_hex_chat, :motd_cache, motd)

      html = render_click(view, "toolbar_action", %{"action" => "show_motd"})

      assert html =~ motd
      assert html =~ ~s(id="status-messages")
    end
  end

  describe "Feature 12 MOTD help documentation" do
    test "help topics describe the MOTD menu entry and cross-reference commands" do
      motd_ui = HelpTopics.get_topic("ui-message-of-the-day")
      cmd_motd = HelpTopics.get_topic("cmd-motd")
      special_messages = HelpTopics.get_topic("feature-special-messages")

      assert motd_ui != nil
      assert "show_motd" in motd_ui.keywords
      assert "Help menu" in motd_ui.keywords
      assert "ui-message-of-the-day" in cmd_motd.see_also
      assert "ui-message-of-the-day" in special_messages.see_also
    end
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp menu_actions(section) do
    section
    |> Floki.find("[data-testid^=\"context-menu-item-\"]")
    |> Enum.map(fn item ->
      item
      |> Floki.attribute("data-testid")
      |> List.first()
      |> String.replace_prefix("context-menu-item-", "")
    end)
  end
end
