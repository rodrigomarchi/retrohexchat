defmodule RetroHexChat.Commands.Handlers.BotTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Commands.Handlers.Bot

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
      assert {:ok, :system, %{content: content}} = Bot.execute(["list"], @user_ctx)
      assert content =~ "BotCmdTest"
    end

    test "shows no bots message when empty" do
      assert {:ok, :system, %{content: content}} = Bot.execute(["list"], @user_ctx)
      assert content =~ "No bots"
    end
  end

  describe "execute info" do
    test "shows bot info" do
      Bot.execute(["create", "BotCmdTest", "A", "test", "bot"], @admin_ctx)
      assert {:ok, :system, %{content: content}} = Bot.execute(["info", "BotCmdTest"], @user_ctx)
      assert content =~ "BotCmdTest"
      assert content =~ "admin"
    end

    test "returns error for unknown bot" do
      assert {:error, msg} = Bot.execute(["info", "Unknown"], @user_ctx)
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
               Bot.execute(["commands", "BotCmdTest"], @user_ctx)

      assert c2 =~ "rules"

      assert {:ok, :system, %{content: c3}} =
               Bot.execute(["delcmd", "BotCmdTest", "rules"], @admin_ctx)

      assert c3 =~ "removed"
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
      assert {:ok, :system, %{content: content}} = Bot.execute(["help"], @user_ctx)
      assert content =~ "/bot create"
    end
  end

  describe "execute with no args" do
    test "admin gets ui_action" do
      assert {:ok, :ui_action, :open_bot_dialog, %{}} = Bot.execute([], @admin_ctx)
    end

    test "regular user gets bot list" do
      assert {:ok, :system, _} = Bot.execute([], @user_ctx)
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
