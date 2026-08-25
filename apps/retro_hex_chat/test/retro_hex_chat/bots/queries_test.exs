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

    test "list_bots_with_associations/0 carries what a roster shows without a query per bot" do
      {:ok, bot} = Queries.create_bot(%{name: "Wired", nickname: "Wired", created_by: "admin"})
      {:ok, _} = Queries.add_channel_config(bot.id, "#news")

      {:ok, _} =
        Queries.add_custom_command(bot.id, %{
          trigger: "sources",
          response: "LWN",
          added_by: "admin"
        })

      [loaded] = Queries.list_bots_with_associations()

      assert Enum.map(loaded.channel_configs, & &1.channel_name) == ["#news"]
      assert Enum.map(loaded.custom_commands, & &1.trigger) == ["sources"]
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

  describe "list_event_logs/2" do
    test "returns events for bot ordered by newest first" do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      {:ok, _} = Queries.log_event(bot.id, "first", "#general")
      {:ok, _} = Queries.log_event(bot.id, "second", "#general")
      {:ok, _} = Queries.log_event(bot.id, "third", "#general")

      events = Queries.list_event_logs(bot.id).items
      assert length(events) == 3
      assert hd(events).event_type == "third"
    end

    test "respects limit parameter" do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)

      for i <- 1..5 do
        Queries.log_event(bot.id, "event_#{i}", "#general")
      end

      events = Queries.list_event_logs(bot.id, limit: 2).items
      assert length(events) == 2
    end

    test "returns empty list for bot with no events" do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      assert Queries.list_event_logs(bot.id).items == []
    end

    test "returns only events for the specified bot_id" do
      {:ok, bot1} = Queries.create_bot(@valid_bot_attrs)

      {:ok, bot2} =
        Queries.create_bot(%{name: "OtherBot", nickname: "OtherBot", created_by: "admin"})

      {:ok, _} = Queries.log_event(bot1.id, "bot1_event", "#general")
      {:ok, _} = Queries.log_event(bot2.id, "bot2_event", "#general")

      events = Queries.list_event_logs(bot1.id).items
      assert length(events) == 1
      assert hd(events).event_type == "bot1_event"
    end
  end

  describe "record_greeting/4" do
    setup do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      {:ok, bot: bot}
    end

    test "the first welcome anywhere is a first time", %{bot: bot} do
      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
    end

    test "a second welcome inside the window is a repeat", %{bot: bot} do
      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
      assert :within_window == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
    end

    test "a welcome past the window is neither a first time nor a repeat", %{bot: bot} do
      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
      assert :window_elapsed == Queries.record_greeting(bot.id, "#lobby", "alice", 0)
    end

    test "the window restarts from the last welcome, not the first", %{bot: bot} do
      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
      assert :window_elapsed == Queries.record_greeting(bot.id, "#lobby", "alice", 0)
      assert :within_window == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
    end

    test "case is folded, so one person is not two newcomers", %{bot: bot} do
      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "Alice", 3600)
      assert :within_window == Queries.record_greeting(bot.id, "#LOBBY", "alice", 3600)
    end

    test "each room meets a person separately", %{bot: bot} do
      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
      assert :first_time == Queries.record_greeting(bot.id, "#retro", "alice", 3600)
    end

    test "each bot meets a person separately", %{bot: bot} do
      {:ok, other} =
        Queries.create_bot(%{name: "OtherBot", nickname: "OtherBot", created_by: "admin"})

      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
      assert :first_time == Queries.record_greeting(other.id, "#lobby", "alice", 3600)
    end

    test "a window of zero still announces only once", %{bot: bot} do
      # No window means everyone is toured again on every join. The public half
      # is not governed by the window at all — it is governed by the row.
      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "alice", 0)
      assert :window_elapsed == Queries.record_greeting(bot.id, "#lobby", "alice", 0)
      assert :window_elapsed == Queries.record_greeting(bot.id, "#lobby", "alice", 0)
    end

    test "destroying a bot forgets who it met", %{bot: bot} do
      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
      {:ok, _} = Queries.delete_bot(bot)

      {:ok, reborn} = Queries.create_bot(@valid_bot_attrs)
      assert :first_time == Queries.record_greeting(reborn.id, "#lobby", "alice", 3600)
    end
  end

  describe "delete_greetings_before/2" do
    setup do
      {:ok, bot} = Queries.create_bot(@valid_bot_attrs)
      {:ok, bot: bot}
    end

    test "drops what is older than the cutoff and keeps the rest", %{bot: bot} do
      :first_time = Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
      :first_time = Queries.record_greeting(bot.id, "#lobby", "bob", 3600)

      future = DateTime.add(DateTime.utc_now(), 60, :second)
      past = DateTime.add(DateTime.utc_now(), -60, :second)

      assert 0 == Queries.count_greetings_before(past)
      assert 2 == Queries.count_greetings_before(future)
      assert 2 == Queries.delete_greetings_before(future)
      assert 0 == Queries.count_greetings_before(future)
    end

    test "a forgotten person is a newcomer again", %{bot: bot} do
      :first_time = Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
      Queries.delete_greetings_before(DateTime.add(DateTime.utc_now(), 60, :second))

      assert :first_time == Queries.record_greeting(bot.id, "#lobby", "alice", 3600)
    end

    test "takes no more than the limit in one pass", %{bot: bot} do
      for nick <- ~w(alice bob carol) do
        :first_time = Queries.record_greeting(bot.id, "#lobby", nick, 3600)
      end

      future = DateTime.add(DateTime.utc_now(), 60, :second)

      assert 2 == Queries.delete_greetings_before(future, limit: 2)
      assert 1 == Queries.count_greetings_before(future)
    end
  end
end
