defmodule RetroHexChatWeb.ChatLive.BotEventsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Bots.{Queries, Supervisor}

  setup do
    on_exit(fn ->
      # Stop bot processes (in-memory cleanup)
      for nickname <- RetroHexChat.Bots.Registry.registered_bots() do
        Supervisor.stop_bot(nickname)
      end
      # DB cleanup is handled by Ecto sandbox rollback

      Application.delete_env(:retro_hex_chat, :admins)
    end)

    :ok
  end

  defp make_admin(nick) do
    current = Application.get_env(:retro_hex_chat, :admins, [])
    Application.put_env(:retro_hex_chat, :admins, [nick | current])
  end

  describe "admin gate" do
    test "non-admin gets error when opening bot dialog", %{conn: conn} do
      nick = "BotNa#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_bot_dialog")
      html = render(view)
      refute html =~ "bot-management-dialog"
      assert html =~ "restricted to server administrators"
    end
  end

  describe "dialog lifecycle" do
    test "open_bot_dialog loads bots and shows dialog", %{conn: conn} do
      nick = "BotEv#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_bot_dialog")
      html = render(view)
      assert html =~ "Bot Management"
    end

    test "close_bot_dialog hides dialog", %{conn: conn} do
      nick = "BotEc#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_bot_dialog")
      render_click(view, "close_bot_dialog")
      html = render(view)
      refute html =~ "bot-management-dialog"
    end
  end

  describe "bot selection" do
    test "bot_select loads bot details", %{conn: conn} do
      nick = "BotSl#{uid()}"
      make_admin(nick)

      {:ok, bot} =
        Queries.create_bot(%{name: "SelectBot", nickname: "SelectBot", created_by: nick})

      Queries.add_channel_config(bot.id, "#testsel")

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "SelectBot"})

      html = render(view)
      assert html =~ "SelectBot"

      # Switch to channels tab to see the channel
      render_click(view, "bot_dialog_tab", %{"tab" => "channels"})
      html = render(view)
      assert html =~ "#testsel"
    end
  end

  describe "CRUD operations" do
    test "create_bot with valid params creates bot", %{conn: conn} do
      nick = "BotCr#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_bot_dialog")
      render_click(view, "open_new_bot_dialog")

      render_submit(view, "create_bot", %{
        "name" => "NewBot",
        "nickname" => "NewBot",
        "description" => "A new bot",
        "prefix" => "!",
        "cooldown" => "2000",
        "cap_mention" => "true",
        "cap_help" => "true"
      })

      html = render(view)
      assert html =~ "NewBot"
      assert Queries.get_bot_by_name("NewBot") != nil
    end

    test "create_bot with duplicate name fails", %{conn: conn} do
      nick = "BotDp#{uid()}"
      make_admin(nick)
      Queries.create_bot(%{name: "DupBot", nickname: "DupBot", created_by: nick})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "open_new_bot_dialog")

      render_submit(view, "create_bot", %{"name" => "DupBot"})

      html = render(view)
      assert html =~ "Failed"
    end

    test "bot_delete removes bot", %{conn: conn} do
      nick = "BotDl#{uid()}"
      make_admin(nick)
      Queries.create_bot(%{name: "DelBot", nickname: "DelBot", created_by: nick})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "DelBot"})
      render_click(view, "bot_delete", %{"name" => "DelBot"})

      html = render(view)
      assert html =~ "destroyed"
      assert Queries.get_bot_by_name("DelBot") == nil
    end
  end

  describe "enable/disable" do
    test "bot_toggle_enabled toggles and refreshes list", %{conn: conn} do
      nick = "BotTg#{uid()}"
      make_admin(nick)
      Queries.create_bot(%{name: "TogBot", nickname: "TogBot", created_by: nick})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_toggle_enabled", %{"name" => "TogBot"})

      html = render(view)
      assert html =~ "disabled"

      bot = Queries.get_bot_by_name("TogBot")
      refute bot.enabled
    end
  end

  describe "channel management" do
    test "bot_add_channel adds config", %{conn: conn} do
      nick = "BotCh#{uid()}"
      make_admin(nick)
      Queries.create_bot(%{name: "ChanBot", nickname: "ChanBot", created_by: nick})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "ChanBot"})

      render_submit(view, "bot_add_channel", %{
        "channel" => "#newchan",
        "bot_name" => "ChanBot"
      })

      html = render(view)
      assert html =~ "#newchan"
    end

    test "bot_add_channel adds # prefix if missing", %{conn: conn} do
      nick = "BotPf#{uid()}"
      make_admin(nick)
      Queries.create_bot(%{name: "PfxBot", nickname: "PfxBot", created_by: nick})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "PfxBot"})

      render_submit(view, "bot_add_channel", %{
        "channel" => "nohash",
        "bot_name" => "PfxBot"
      })

      html = render(view)
      assert html =~ "#nohash"
    end

    test "bot_remove_channel removes config", %{conn: conn} do
      nick = "BotRm#{uid()}"
      make_admin(nick)
      {:ok, bot} = Queries.create_bot(%{name: "RmBot", nickname: "RmBot", created_by: nick})
      Queries.add_channel_config(bot.id, "#removeme")

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "RmBot"})

      render_click(view, "bot_remove_channel", %{
        "channel" => "#removeme",
        "bot_name" => "RmBot"
      })

      html = render(view)
      assert html =~ "left #removeme"
    end
  end

  describe "command management" do
    test "bot_add_command creates command", %{conn: conn} do
      nick = "BotAc#{uid()}"
      make_admin(nick)
      Queries.create_bot(%{name: "CmdBot", nickname: "CmdBot", created_by: nick})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "CmdBot"})
      render_click(view, "open_add_command_dialog")

      render_submit(view, "bot_add_command", %{
        "bot_name" => "CmdBot",
        "trigger" => "rules",
        "response" => "Read #rules",
        "description" => "Show rules"
      })

      html = render(view)
      assert html =~ "rules"
    end

    test "bot_remove_command deletes command", %{conn: conn} do
      nick = "BotRc#{uid()}"
      make_admin(nick)
      {:ok, bot} = Queries.create_bot(%{name: "RcBot", nickname: "RcBot", created_by: nick})

      Queries.add_custom_command(bot.id, %{
        trigger: "faq",
        response: "Check FAQ",
        added_by: nick
      })

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "RcBot"})

      render_click(view, "bot_remove_command", %{
        "trigger" => "faq",
        "bot_name" => "RcBot"
      })

      html = render(view)
      assert html =~ "removed"
    end
  end

  describe "inline editing" do
    test "bot_edit_field sets editing mode", %{conn: conn} do
      nick = "BotEf#{uid()}"
      make_admin(nick)
      Queries.create_bot(%{name: "EdBot", nickname: "EdBot", created_by: nick})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "EdBot"})
      render_click(view, "bot_edit_field", %{"field" => "description"})

      html = render(view)
      assert html =~ "bot-mgmt-inline-edit"
    end

    test "bot_update_field updates description", %{conn: conn} do
      nick = "BotUd#{uid()}"
      make_admin(nick)
      Queries.create_bot(%{name: "UpdBot", nickname: "UpdBot", created_by: nick})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "UpdBot"})

      render_submit(view, "bot_update_field", %{
        "bot_name" => "UpdBot",
        "field" => "description",
        "value" => "Updated desc"
      })

      html = render(view)
      assert html =~ "Description updated"

      bot = Queries.get_bot_by_name("UpdBot")
      assert bot.description == "Updated desc"
    end

    test "bot_update_field rejects invalid cooldown", %{conn: conn} do
      nick = "BotIc#{uid()}"
      make_admin(nick)
      Queries.create_bot(%{name: "IcBot", nickname: "IcBot", created_by: nick})

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "IcBot"})

      render_submit(view, "bot_update_field", %{
        "bot_name" => "IcBot",
        "field" => "cooldown",
        "value" => "100"
      })

      html = render(view)
      assert html =~ "at least 500ms"
    end
  end

  describe "capability management" do
    test "bot_toggle_capability disables capability", %{conn: conn} do
      nick = "BotTc#{uid()}"
      make_admin(nick)

      Queries.create_bot(%{
        name: "TcBot",
        nickname: "TcBot",
        created_by: nick,
        capabilities: %{
          "dice" => %{"enabled" => true, "max_dice" => 100}
        }
      })

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      render_click(view, "open_bot_dialog")
      render_click(view, "bot_select", %{"name" => "TcBot"})

      render_click(view, "bot_toggle_capability", %{
        "capability" => "dice",
        "bot_name" => "TcBot"
      })

      html = render(view)
      assert html =~ "disabled"

      bot = Queries.get_bot_by_name("TcBot")
      refute bot.capabilities["dice"]["enabled"]
    end
  end
end
