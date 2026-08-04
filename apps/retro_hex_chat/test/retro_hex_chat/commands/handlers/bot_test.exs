defmodule RetroHexChat.Commands.Handlers.BotTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Commands.Handlers.Bot

  @bold <<0x02>>
  @colour <<0x03>>
  @reset <<0x0F>>

  @admin_ctx %{
    nickname: "admin",
    active_channel: "#general",
    channels: ["#general"],
    identified: true,
    operator_in: [],
    half_operator_in: [],
    is_admin: true,
    is_server_operator: false
  }

  @user_ctx %{
    nickname: "user",
    active_channel: "#general",
    channels: ["#general"],
    identified: false,
    operator_in: [],
    half_operator_in: [],
    is_admin: false,
    is_server_operator: false
  }

  setup do
    on_exit(fn ->
      RetroHexChat.Bots.Supervisor.stop_bot("BotCmdTest")
    end)

    :ok
  end

  describe "execute create" do
    test "admin can create a bot" do
      assert {:ok, :system, %{content: content}} =
               Bot.execute(["create", "BotCmdTest", "A", "test"], @admin_ctx)

      assert content =~ "created"
    end

    test "regular user cannot create" do
      assert {:error, msg} = Bot.execute(["create", "BotCmdTest"], @user_ctx)
      assert msg =~ "Only admins"
    end

    test "rejects duplicate bot name" do
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)
      assert {:error, msg} = Bot.execute(["create", "BotCmdTest"], @admin_ctx)
      assert msg =~ "Failed"
    end
  end

  describe "execute list" do
    test "lists bots" do
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)
      assert {:ok, :system, %{content: content}} = Bot.execute(["list"], @admin_ctx)
      assert content =~ "BotCmdTest"
    end

    test "shows no bots message when empty" do
      assert {:ok, :system, %{content: content}} = Bot.execute(["list"], @admin_ctx)
      assert content =~ "No bots"
    end
  end

  describe "execute info" do
    test "shows bot info" do
      Bot.execute(["create", "BotCmdTest", "A", "test", "bot"], @admin_ctx)
      assert {:ok, :system, %{content: content}} = Bot.execute(["info", "BotCmdTest"], @admin_ctx)
      assert content =~ "BotCmdTest"
      assert content =~ "admin"
    end

    test "returns error for unknown bot" do
      assert {:error, msg} = Bot.execute(["info", "Unknown"], @admin_ctx)
      assert msg =~ "not found"
    end
  end

  describe "execute enable/disable" do
    test "toggles bot enabled state" do
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)
      assert {:ok, :system, %{content: c1}} = Bot.execute(["disable", "BotCmdTest"], @admin_ctx)
      assert c1 =~ "disabled"

      assert {:ok, :system, %{content: c2}} = Bot.execute(["enable", "BotCmdTest"], @admin_ctx)
      assert c2 =~ "enabled"
    end
  end

  describe "execute addcmd/delcmd" do
    test "adds and removes custom commands" do
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)

      assert {:ok, :system, %{content: c}} =
               Bot.execute(["addcmd", "BotCmdTest", "rules", "Read", "#rules"], @admin_ctx)

      assert c =~ "set for"

      assert {:ok, :system, %{content: c2}} =
               Bot.execute(["commands", "BotCmdTest"], @admin_ctx)

      assert c2 =~ "rules"

      assert {:ok, :system, %{content: c3}} =
               Bot.execute(["delcmd", "BotCmdTest", "rules"], @admin_ctx)

      assert c3 =~ "removed"
    end

    test "decodes IRC formatting escapes in custom command responses" do
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)

      assert {:ok, :system, _} =
               Bot.execute(
                 ["addcmd", "BotCmdTest", "alert", "\\c04\\bAlert\\o", "{nickname}"],
                 @admin_ctx
               )

      cmd =
        "BotCmdTest"
        |> Queries.get_bot_by_name()
        |> then(&Queries.list_custom_commands(&1.id))
        |> Enum.find(&(&1.trigger == "alert"))

      assert cmd.response == @colour <> "04" <> @bold <> "Alert" <> @reset <> " {nickname}"
    end
  end

  describe "execute set — capabilities absent at creation" do
    # A bot is born with greeter, custom_commands and help. Every other
    # capability is created by the first `/bot set` that names one of its keys,
    # and that first write is the one that used to be dropped.
    setup do
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)
      :ok
    end

    defp capabilities do
      Queries.get_bot_by_name("BotCmdTest").capabilities
    end

    test "the first mention_response is stored, not swallowed" do
      assert {:ok, :system, _} =
               Bot.execute(["set", "BotCmdTest", "mention_response", "You", "rang?"], @admin_ctx)

      assert %{"mention" => %{"response" => "You rang?"}} = capabilities()
    end

    test "the first trivia setting keeps its value" do
      assert {:ok, :system, _} =
               Bot.execute(["set", "BotCmdTest", "trivia_category", "science"], @admin_ctx)

      assert %{"trivia" => %{"category" => "science"}} = capabilities()
    end

    test "the first numeric setting keeps its value" do
      assert {:ok, :system, _} =
               Bot.execute(["set", "BotCmdTest", "dice_max_dice", "50"], @admin_ctx)

      assert %{"dice" => %{"max_dice" => 50}} = capabilities()
    end

    test "a later setting on the same capability does not erase the earlier one" do
      Bot.execute(["set", "BotCmdTest", "trivia_category", "science"], @admin_ctx)
      Bot.execute(["set", "BotCmdTest", "trivia_points", "25"], @admin_ctx)

      assert %{"trivia" => %{"category" => "science", "points_per_answer" => 25}} =
               capabilities()
    end

    test "greeting reaches a bot that already owns the greeter capability" do
      assert {:ok, :system, _} =
               Bot.execute(["set", "BotCmdTest", "greeting", "Welcome", "aboard"], @admin_ctx)

      assert %{"greeter" => %{"greeting" => "Welcome aboard"}} = capabilities()
    end

    test "bot speech settings decode IRC formatting escapes before storage" do
      assert {:ok, :system, _} =
               Bot.execute(
                 ["set", "BotCmdTest", "greeting", "\\c03\\bWelcome\\o", "{nickname}"],
                 @admin_ctx
               )

      assert {:ok, :system, _} =
               Bot.execute(
                 ["set", "BotCmdTest", "mention_response", "\\c06\\bYou", "rang?\\o"],
                 @admin_ctx
               )

      assert {:ok, :system, _} =
               Bot.execute(
                 ["set", "BotCmdTest", "mod_warn", "\\c04\\bCareful\\o", "{nickname}"],
                 @admin_ctx
               )

      assert %{
               "greeter" => %{
                 "greeting" => @colour <> "03" <> @bold <> "Welcome" <> @reset <> " {nickname}"
               },
               "mention" => %{
                 "response" => @colour <> "06" <> @bold <> "You rang?" <> @reset
               },
               "moderation" => %{
                 "warn_message" =>
                   @colour <> "04" <> @bold <> "Careful" <> @reset <> " {nickname}"
               }
             } = capabilities()
    end

    test "greeter delivery and repeat window settings are stored" do
      assert {:ok, :system, _} =
               Bot.execute(
                 ["set", "BotCmdTest", "greeting_delivery", "private_notice"],
                 @admin_ctx
               )

      assert {:ok, :system, _} =
               Bot.execute(["set", "BotCmdTest", "farewell_delivery", "silent"], @admin_ctx)

      assert {:ok, :system, _} =
               Bot.execute(["set", "BotCmdTest", "greeter_repeat_window", "43200"], @admin_ctx)

      assert %{
               "greeter" => %{
                 "greeting_delivery" => "private_notice",
                 "farewell_delivery" => "silent",
                 "repeat_window_sec" => 43_200
               }
             } = capabilities()
    end

    test "greeter delivery rejects unknown modes" do
      assert {:error, msg} =
               Bot.execute(["set", "BotCmdTest", "greeting_delivery", "global"], @admin_ctx)

      assert msg =~ "greeting_delivery must be one of"
    end
  end

  describe "execute rss — seeding feeds from a script" do
    alias RetroHexChat.Bots.Feeds

    @public "https://93.184.216.34/feed.xml"

    setup do
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)
      bot = Queries.get_bot_by_name("BotCmdTest")
      {:ok, _} = Queries.add_channel_config(bot.id, "#wire")
      :ok
    end

    test "adds a feed to a bot" do
      assert {:ok, :system, %{content: content}} =
               Bot.execute(["rss", "add", "BotCmdTest", @public, "#wire"], @admin_ctx)

      assert content =~ "Feed added"

      assert [%{"url" => @public, "channel" => "#wire"}] =
               Feeds.list(Queries.get_bot_by_name("BotCmdTest"))
    end

    test "refuses an address the server should not fetch" do
      assert {:error, msg} =
               Bot.execute(
                 ["rss", "add", "BotCmdTest", "http://169.254.169.254/x", "#wire"],
                 @admin_ctx
               )

      assert msg =~ "public"
    end

    test "refuses a room the bot has not joined" do
      assert {:error, msg} =
               Bot.execute(["rss", "add", "BotCmdTest", @public, "#elsewhere"], @admin_ctx)

      assert msg =~ "not in #elsewhere"
    end

    test "a regular user cannot point a bot at a URL" do
      assert {:error, msg} =
               Bot.execute(["rss", "add", "BotCmdTest", @public, "#wire"], @user_ctx)

      assert msg =~ "Only admins"
    end

    test "lists what a bot carries, and says so when it carries nothing" do
      assert {:ok, :system, %{content: empty}} =
               Bot.execute(["rss", "list", "BotCmdTest"], @admin_ctx)

      assert empty =~ "no feeds"

      Bot.execute(["rss", "add", "BotCmdTest", @public, "#wire"], @admin_ctx)

      assert {:ok, :system, %{content: listed}} =
               Bot.execute(["rss", "list", "BotCmdTest"], @admin_ctx)

      assert listed =~ @public
      assert listed =~ "#wire"
      assert listed =~ "never"
    end

    test "removes a feed by the id it was given" do
      Bot.execute(["rss", "add", "BotCmdTest", @public, "#wire"], @admin_ctx)
      [%{"id" => id}] = Feeds.list(Queries.get_bot_by_name("BotCmdTest"))

      assert {:ok, :system, %{content: content}} =
               Bot.execute(["rss", "remove", "BotCmdTest", id], @admin_ctx)

      assert content =~ "removed"
      assert Feeds.list(Queries.get_bot_by_name("BotCmdTest")) == []
    end
  end

  describe "execute destroy" do
    test "admin can destroy a bot" do
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)

      assert {:ok, :system, %{content: content}} =
               Bot.execute(["destroy", "BotCmdTest"], @admin_ctx)

      assert content =~ "destroyed"
    end
  end

  describe "execute help" do
    test "shows help text" do
      assert {:ok, :system, %{content: content}} = Bot.execute(["help"], @admin_ctx)
      assert content =~ "/bot create"
    end
  end

  describe "execute with no args" do
    test "admin gets ui_action" do
      assert {:ok, :ui_action, :open_bot_dialog, %{}} = Bot.execute([], @admin_ctx)
    end
  end

  # A bot's roster, its settings, the commands written for it and the addresses
  # it fetches are all server configuration. Reading them is the first half of
  # changing them, and the feed list is a map of what the server reaches out to.
  describe "the whole command is administrative" do
    test "every read is refused to a regular user" do
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)

      reads = [
        [],
        ["list"],
        ["info", "BotCmdTest"],
        ["commands", "BotCmdTest"],
        ["rss", "list", "BotCmdTest"],
        ["help"]
      ]

      for args <- reads do
        assert {:error, msg} = Bot.execute(args, @user_ctx),
               "#{inspect(args)} answered a user who may not manage bots"

        assert msg =~ "Only admins",
               "#{inspect(args)} refused for the wrong reason"
      end
    end

    test "a refusal says nothing about which bots exist" do
      # Same answer for a real bot and an invented one: the refusal must not
      # become a way to probe the roster.
      Bot.execute(["create", "BotCmdTest"], @admin_ctx)

      assert {:error, real} = Bot.execute(["info", "BotCmdTest"], @user_ctx)
      assert {:error, invented} = Bot.execute(["info", "NoSuchBot"], @user_ctx)
      assert real == invented
    end
  end

  describe "help/0" do
    test "returns help metadata" do
      h = Bot.help()
      assert h.name == "bot"
      assert is_binary(h.syntax)
      assert is_list(h.examples)
    end
  end
end
