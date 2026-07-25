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
        |> Enum.find(fn section ->
          section
          |> Floki.find(~s(button[data-testid="app-menu-help-trigger"]))
          |> Enum.any?()
        end)

      assert help_section
      assert "show_motd" in menu_actions(help_section)
      assert Floki.raw_html(help_section) =~ "Message of the Day"
    end

    test "toolbar action show_motd renders the current MOTD in Status", %{conn: conn} do
      view = connect_user(conn, "MotdView#{uid()}")
      motd = "motd-menu-marker-#{uid()}"

      Application.put_env(:retro_hex_chat, :motd_cache, motd)

      render_click(view, "toolbar_action", %{"action" => "show_motd"})

      # The MOTD line is appended via the StatusViewport island's async
      # send_update — flush with a render before asserting it.
      html = render(view)
      assert html =~ motd
      assert html =~ ~s(id="status-messages")
    end
  end

  describe "Feature 12 MOTD help documentation" do
    test "help topics describe the MOTD menu entry and cross-reference commands" do
      motd_ui = HelpTopics.get_topic("ui-message-of-the-day")
      cmd_motd = HelpTopics.get_topic("cmd-motd")
      special_messages = HelpTopics.get_topic("feature-special-messages")
      admin_console = HelpTopics.get_topic("feature-admin-console")

      assert motd_ui != nil
      assert "show_motd" in motd_ui.keywords
      assert "Help menu" in motd_ui.keywords
      assert "ui-message-of-the-day" in cmd_motd.see_also
      assert "ui-message-of-the-day" in special_messages.see_also
      assert "cmd-setmotd" in admin_console.see_also
      assert "cmd-clearmotd" in admin_console.see_also
      assert "cmd-admin-nuke" in admin_console.see_also

      # Each split-out window owns the keywords for what it does.
      for {topic_id, keyword} <- [
            {"feature-admin-users", "user moderation"},
            {"feature-admin-channels", "chanserv admin"},
            {"feature-admin-server-settings", "server settings"},
            {"feature-admin-motd", "motd"},
            {"feature-admin-broadcast", "wallops"},
            {"feature-admin-audit-log", "audit log"},
            {"feature-admin-turn", "turn"},
            {"feature-admin-danger-zone", "danger zone"}
          ] do
        topic = HelpTopics.get_topic(topic_id)
        assert topic != nil, "missing help topic #{topic_id}"
        assert keyword in topic.keywords, "#{topic_id} should own the #{keyword} keyword"
        assert "feature-admin-console" in topic.see_also
      end

      admin_user = HelpTopics.get_topic("cmd-admin-user")

      assert "admin users" in admin_user.keywords
      assert "feature-admin-users" in admin_user.see_also

      admin_channels = HelpTopics.get_topic("feature-admin-channels")

      assert "chanserv admin" in admin_channels.keywords
      assert "cmd-admin-channel" in admin_channels.see_also

      admin_channel = HelpTopics.get_topic("cmd-admin-channel")

      assert "feature-admin-channels" in admin_channel.see_also

      admin_cs = HelpTopics.get_topic("cmd-admin-cs")

      assert "chanserv admin" in admin_cs.keywords
      assert "feature-admin-console" in admin_cs.see_also

      broadcasts = HelpTopics.get_topic("feature-server-broadcasts")

      assert broadcasts != nil
      assert "wallops" in broadcasts.keywords
      assert "announce" in broadcasts.keywords
      assert "cmd-wallops" in broadcasts.see_also
      assert "cmd-announce" in broadcasts.see_also
      assert "feature-server-broadcasts" in admin_console.see_also
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
