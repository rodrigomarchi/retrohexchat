defmodule RetroHexChat.Bots.QueriesTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Bots.Queries

  @valid_bot_attrs %{name: "TestBot", nickname: "TestBot", created_by: "admin"}

  describe "bot CRUD" do
    test "create_bot/1 with valid attrs" do
      assert {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      assert bot.name == "TestBot"
      assert bot.nickname == "TestBot"
      assert bot.created_by == "admin"
      assert bot.enabled == true
      assert bot.command_prefix == "!"
    end

    test "create_bot/1 enforces unique name" do
      {:ok, _} = Queries.create_bot(@valid_bot_attrs)
      {:error, cs} = Queries.create_bot(@valid_bot_attrs)
      assert {"has already been taken", _} = cs.errors[:name]
    end

    test "get_bot/1 returns bot by id" do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      assert Queries.get_bot(bot.id).name == "TestBot"
    end

    test "get_bot_by_name/1 returns bot" do
      {:ok, _} = Queries.create_bot(@valid_bot_attrs)
      assert Queries.get_bot_by_name("TestBot").name == "TestBot"
      assert is_nil(Queries.get_bot_by_name("NonExistent"))
    end

    test "get_bot_by_nickname/1 returns bot" do
      {:ok, _} = Queries.create_bot(@valid_bot_attrs)
      assert Queries.get_bot_by_nickname("TestBot").nickname == "TestBot"
    end

    test "list_bots/0 returns all bots ordered by name" do
      {:ok, _} = Queries.create_bot(%{name: "ZBot", nickname: "ZBot", created_by: "admin"})
      {:ok, _} = Queries.create_bot(%{name: "ABot", nickname: "ABot", created_by: "admin"})
      bots = Queries.list_bots()
      assert length(bots) == 2
      assert hd(bots).name == "ABot"
    end

    test "list_bots_by_creator/1 filters by creator" do
      {:ok, _} = Queries.create_bot(@valid_bot_attrs)
      {:ok, _} = Queries.create_bot(%{name: "Other", nickname: "Other", created_by: "other"})
      assert length(Queries.list_bots_by_creator("admin")) == 1
    end

    test "update_bot/2 updates optional fields" do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      {:ok, updated} = Queries.update_bot(bot, %{description: "A test bot"})
      assert updated.description == "A test bot"
    end

    test "delete_bot/1 removes the bot" do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      {:ok, _} = Queries.delete_bot(bot)
      assert is_nil(Queries.get_bot(bot.id))
    end
  end

  describe "channel configs" do
    setup do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      %{bot: bot}
    end

    test "add and list channel configs", %{bot: bot} do
      {:ok, config} = Queries.add_channel_config(bot.id, "#general")
      assert config.channel_name == "#general"
      assert config.enabled == true

      configs = Queries.list_channel_configs(bot.id)
      assert length(configs) == 1
    end

    test "remove channel config", %{bot: bot} do
      {:ok, _} = Queries.add_channel_config(bot.id, "#general")
      :ok = Queries.remove_channel_config(bot.id, "#general")
      assert Queries.list_channel_configs(bot.id) == []
    end

    test "unique constraint on bot_id + channel_name", %{bot: bot} do
      {:ok, _} = Queries.add_channel_config(bot.id, "#general")
      {:error, _} = Queries.add_channel_config(bot.id, "#general")
    end
  end

  describe "custom commands" do
    setup do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      %{bot: bot}
    end

    test "add and list custom commands", %{bot: bot} do
      attrs = %{trigger: "rules", response: "Read #rules", added_by: "admin"}
      {:ok, cmd} = Queries.add_custom_command(bot.id, attrs)
      assert cmd.trigger == "rules"

      cmds = Queries.list_custom_commands(bot.id)
      assert length(cmds) == 1
    end

    test "remove custom command", %{bot: bot} do
      attrs = %{trigger: "faq", response: "Check FAQ", added_by: "admin"}
      {:ok, _} = Queries.add_custom_command(bot.id, attrs)
      :ok = Queries.remove_custom_command(bot.id, "faq")
      assert Queries.list_custom_commands(bot.id) == []
    end
  end

  describe "event log" do
    test "log_event/4 creates a log entry" do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      {:ok, log} = Queries.log_event(bot.id, "message_handled", "#general", %{"content" => "hi"})
      assert log.event_type == "message_handled"
      assert log.channel == "#general"
    end
  end
end
