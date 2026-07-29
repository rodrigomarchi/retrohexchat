defmodule RetroHexChat.Bots.ServerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.{Registry, Server, Supervisor}

  @bot_data %{
    id: 999,
    name: "ServerTestBot",
    nickname: "ServerTestBot",
    command_prefix: "!",
    created_by: "admin",
    enabled: true,
    cooldown_ms: 100,
    capabilities: %{
      "mention" => %{"response" => "Hi {nickname}!", "enabled" => true},
      "greeter" => %{"greeting" => "Welcome {nickname}!", "enabled" => true},
      "help" => %{"enabled" => true},
      "custom_commands" => %{"enabled" => true}
    },
    channel_configs: [],
    custom_commands: []
  }

  setup do
    on_exit(fn ->
      # Clean up any running bot
      Supervisor.stop_bot("ServerTestBot")
    end)

    :ok
  end

  describe "start_link/1" do
    test "starts a bot process" do
      {:ok, pid} = Supervisor.start_bot(@bot_data)
      assert Process.alive?(pid)
      assert {:ok, ^pid} = Registry.lookup("ServerTestBot")
    end

    test "registered in BotRegistry" do
      {:ok, _pid} = Supervisor.start_bot(@bot_data)
      assert "ServerTestBot" in Registry.registered_bots()
    end
  end

  describe "get_state/1" do
    test "returns bot state" do
      {:ok, _} = Supervisor.start_bot(@bot_data)
      {:ok, state} = Server.get_state("ServerTestBot")
      assert state.name == "ServerTestBot"
      assert state.nickname == "ServerTestBot"
      assert state.command_prefix == "!"
      assert state.enabled == true
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Server.get_state("NonExistent")
    end
  end

  describe "set_enabled/2" do
    test "toggles enabled state" do
      {:ok, _} = Supervisor.start_bot(@bot_data)
      :ok = Server.set_enabled("ServerTestBot", false)
      {:ok, state} = Server.get_state("ServerTestBot")
      refute state.enabled
    end
  end

  describe "update_config/2" do
    test "updates config values" do
      {:ok, _} = Supervisor.start_bot(@bot_data)
      :ok = Server.update_config("ServerTestBot", %{cooldown_ms: 5000})
      {:ok, state} = Server.get_state("ServerTestBot")
      assert state.cooldown_ms == 5000
    end
  end

  describe "reload_commands/2" do
    test "updates custom commands" do
      {:ok, _} = Supervisor.start_bot(@bot_data)

      commands = %{
        "rules" => %{"response" => "Read #rules", "description" => "Rules", "enabled" => true}
      }

      Server.reload_commands("ServerTestBot", commands)
      {:ok, state} = Server.get_state("ServerTestBot")
      assert Map.has_key?(state.custom_commands, "rules")
    end
  end

  describe "bot-to-bot message isolation" do
    @isolation_bot_a %{
      id: 993,
      name: "BotAlpha",
      nickname: "BotAlpha",
      command_prefix: "!",
      created_by: "admin",
      enabled: true,
      cooldown_ms: 100,
      capabilities: %{
        "mention" => %{"response" => "Hi {nickname}!", "enabled" => true}
      },
      channel_configs: [
        %{channel_name: "#isotest", enabled: true, capability_overrides: %{}}
      ],
      custom_commands: []
    }

    @isolation_bot_b %{
      id: 994,
      name: "BotBeta",
      nickname: "BotBeta",
      command_prefix: "!",
      created_by: "admin",
      enabled: true,
      cooldown_ms: 100,
      capabilities: %{
        "mention" => %{"response" => "Hi {nickname}!", "enabled" => true}
      },
      channel_configs: [
        %{channel_name: "#isotest", enabled: true, capability_overrides: %{}}
      ],
      custom_commands: []
    }

    setup do
      on_exit(fn ->
        Supervisor.stop_bot("BotAlpha")
        Supervisor.stop_bot("BotBeta")
      end)

      :ok
    end

    test "bot ignores messages from other bots" do
      {:ok, _} = Supervisor.start_bot(@isolation_bot_a)
      {:ok, pid_b} = Supervisor.start_bot(@isolation_bot_b)

      # BotAlpha sends a message — BotBeta should ignore it
      send(pid_b, %{
        event: "new_message",
        payload: %{
          id: 1,
          channel: "#isotest",
          author: "BotAlpha",
          content: "BotBeta hi",
          type: :message,
          timestamp: DateTime.utc_now(),
          reply_to_id: nil,
          reply_to_author: nil,
          reply_to_preview: nil
        }
      })

      Process.sleep(50)

      assert Process.alive?(pid_b)
      state = :sys.get_state(pid_b)
      # Should NOT have responded (no cooldown recorded)
      refute Map.has_key?(state.last_response_at, "#isotest")
    end

    test "bot still responds to human messages" do
      {:ok, _} = Supervisor.start_bot(@isolation_bot_a)
      {:ok, pid_b} = Supervisor.start_bot(@isolation_bot_b)

      # Human sends a message — BotBeta should respond
      send(pid_b, %{
        event: "new_message",
        payload: %{
          id: 2,
          channel: "#isotest",
          author: "HumanUser",
          content: "BotBeta hi",
          type: :message,
          timestamp: DateTime.utc_now(),
          reply_to_id: nil,
          reply_to_author: nil,
          reply_to_preview: nil
        }
      })

      Process.sleep(50)

      assert Process.alive?(pid_b)
      state = :sys.get_state(pid_b)
      assert Map.has_key?(state.last_response_at, "#isotest")
    end
  end

  describe "reload_capabilities/2" do
    test "initializes state for newly added capabilities" do
      {:ok, _} = Supervisor.start_bot(@bot_data)

      # Initially no moderation
      {:ok, cap_state} = Server.get_capability_state("ServerTestBot", :moderation)
      assert cap_state == %{}

      # Add moderation via reload
      new_caps =
        Map.put(@bot_data.capabilities, "moderation", %{
          "enabled" => true,
          "spam_threshold" => 5,
          "flood_threshold" => 8,
          "warn_message" => "Behave!"
        })

      :ok = Server.reload_capabilities("ServerTestBot", new_caps)

      # Moderation state should now be properly initialized
      {:ok, cap_state} = Server.get_capability_state("ServerTestBot", :moderation)
      assert Map.has_key?(cap_state, :message_history)
      assert Map.has_key?(cap_state, :warnings)
    end

    test "preserves existing capability states on reload" do
      {:ok, pid} = Supervisor.start_bot(@bot_data)

      # Inject some state into greeter capability
      :sys.replace_state(pid, fn s ->
        %{s | capability_states: Map.put(s.capability_states, :greeter, %{some: :data})}
      end)

      # Reload capabilities (same set)
      :ok = Server.reload_capabilities("ServerTestBot", @bot_data.capabilities)

      # Greeter state should be preserved
      {:ok, cap_state} = Server.get_capability_state("ServerTestBot", :greeter)
      assert cap_state == %{some: :data}
    end

    test "bot survives message after moderation added via reload" do
      bot_data = %{
        @bot_data
        | id: 995,
          name: "ReloadModBot",
          nickname: "ReloadModBot",
          channel_configs: [
            %{channel_name: "#reloadtest", enabled: true, capability_overrides: %{}}
          ]
      }

      {:ok, pid} = Supervisor.start_bot(bot_data)
      on_exit(fn -> Supervisor.stop_bot("ReloadModBot") end)

      # Add moderation
      new_caps =
        Map.put(bot_data.capabilities, "moderation", %{
          "enabled" => true,
          "spam_threshold" => 5,
          "flood_threshold" => 8,
          "warn_message" => "Behave, {nickname}!"
        })

      :ok = Server.reload_capabilities("ReloadModBot", new_caps)

      # Send a message — should NOT crash
      send(pid, %{
        event: "new_message",
        payload: %{
          id: 1,
          channel: "#reloadtest",
          author: "user",
          content: "hello world",
          type: :message,
          timestamp: DateTime.utc_now(),
          reply_to_id: nil,
          reply_to_author: nil,
          reply_to_preview: nil
        }
      })

      Process.sleep(50)
      assert Process.alive?(pid)
    end
  end

  describe "capability_overrides" do
    @overrides_bot %{
      id: 996,
      name: "OverridesBot",
      nickname: "OverridesBot",
      command_prefix: "!",
      created_by: "admin",
      enabled: true,
      cooldown_ms: 100,
      capabilities: %{
        "dice" => %{
          "enabled" => true,
          "max_dice" => 100,
          "max_sides" => 1000,
          "default_notation" => "d20"
        },
        "mention" => %{"response" => "Hi {nickname}!", "enabled" => true}
      },
      channel_configs: [
        %{
          channel_name: "#overtest",
          enabled: true,
          capability_overrides: %{"dice" => %{"max_dice" => 2}}
        }
      ],
      custom_commands: []
    }

    setup do
      on_exit(fn -> Supervisor.stop_bot("OverridesBot") end)
      :ok
    end

    test "channel overrides are stored in state" do
      {:ok, pid} = Supervisor.start_bot(@overrides_bot)
      state = :sys.get_state(pid)
      channel_config = state.channels["#overtest"]
      assert channel_config.capability_overrides == %{"dice" => %{"max_dice" => 2}}
    end

    test "empty overrides map works" do
      bot = %{
        @overrides_bot
        | channel_configs: [
            %{channel_name: "#overtest", enabled: true, capability_overrides: %{}}
          ]
      }

      {:ok, pid} = Supervisor.start_bot(bot)
      state = :sys.get_state(pid)
      assert state.channels["#overtest"].capability_overrides == %{}
    end

    test "overrides for non-existent capability are ignored gracefully" do
      bot = %{
        @overrides_bot
        | channel_configs: [
            %{
              channel_name: "#overtest",
              enabled: true,
              capability_overrides: %{"nonexistent" => %{"foo" => "bar"}}
            }
          ]
      }

      {:ok, pid} = Supervisor.start_bot(bot)
      assert Process.alive?(pid)
    end
  end

  describe "timer rescheduling" do
    @timer_bot %{
      id: 998,
      name: "TimerTestBot",
      nickname: "TimerTestBot",
      command_prefix: "!",
      created_by: "admin",
      enabled: true,
      cooldown_ms: 100,
      capabilities: %{
        "scheduler" => %{
          "enabled" => true,
          "max_schedules" => 10,
          "min_interval_min" => 1,
          "schedules" => [
            %{
              "id" => "s1",
              "type" => "interval",
              "interval_min" => 1,
              "channel" => "#timertest",
              "message" => "Tick!"
            }
          ]
        }
      },
      channel_configs: [%{channel_name: "#timertest", enabled: true, capability_overrides: %{}}],
      custom_commands: []
    }

    setup do
      on_exit(fn -> Supervisor.stop_bot("TimerTestBot") end)
      :ok
    end

    test "scheduler timer is set up during init" do
      {:ok, pid} = Supervisor.start_bot(@timer_bot)
      state = :sys.get_state(pid)
      assert map_size(state.capability_timers) >= 1

      # Verify it's a scheduler timer
      {_ref, {cap_name, _payload}} = Enum.at(state.capability_timers, 0)
      assert cap_name == :scheduler
    end

    test "timer fires and reschedules automatically" do
      # Use nil channel so maybe_respond_timer skips sending (avoids Channels.Server crash)
      bot =
        put_in(@timer_bot.capabilities["scheduler"]["schedules"], [
          %{
            "id" => "s1",
            "type" => "interval",
            "interval_min" => 1,
            "channel" => nil,
            "message" => "Tick!"
          }
        ])

      bot = %{bot | channel_configs: []}

      {:ok, pid} = Supervisor.start_bot(bot)

      # Cancel existing init timers so we can track new ones
      :sys.replace_state(pid, fn s -> %{s | capability_timers: %{}} end)

      # Manually send a timer message to simulate firing
      send(pid, {:capability_timer, :scheduler, %{schedule_id: "s1", channel: nil}})

      # Give it a moment to process
      Process.sleep(50)

      state_after = :sys.get_state(pid)
      # Should have rescheduled — new timer should exist
      scheduler_timers =
        Enum.filter(state_after.capability_timers, fn {_ref, {name, _}} -> name == :scheduler end)

      assert scheduler_timers != []
    end

    test "does not reschedule if schedule was removed" do
      bot = %{@timer_bot | channel_configs: []}
      {:ok, pid} = Supervisor.start_bot(bot)

      # Remove the schedule from capability state and clear existing timers
      :sys.replace_state(pid, fn s ->
        new_cap_states = Map.put(s.capability_states, :scheduler, %{schedules: []})
        %{s | capability_states: new_cap_states, capability_timers: %{}}
      end)

      # Fire the timer for a schedule that no longer exists
      send(pid, {:capability_timer, :scheduler, %{schedule_id: "s1", channel: nil}})
      Process.sleep(50)

      state_after = :sys.get_state(pid)

      scheduler_timers =
        Enum.filter(state_after.capability_timers, fn {_ref, {name, _}} -> name == :scheduler end)

      assert scheduler_timers == []
    end

    test "capability without reschedule_delay does not crash" do
      # Help capability has no reschedule_delay
      bot = %{
        @bot_data
        | id: 997,
          name: "NoTimerBot",
          nickname: "NoTimerBot"
      }

      on_exit(fn -> Supervisor.stop_bot("NoTimerBot") end)

      {:ok, pid} = Supervisor.start_bot(bot)

      # Send a timer for help (which doesn't implement handle_timer or reschedule_delay)
      send(pid, {:capability_timer, :help, %{some: :payload}})
      Process.sleep(50)

      # Bot should still be alive
      assert Process.alive?(pid)
    end
  end

  describe "greeting and the newcomer's first command" do
    @greeter_bot %{
      id: 993,
      name: "GreetCooldownBot",
      nickname: "GreetCooldownBot",
      command_prefix: "!",
      created_by: "admin",
      enabled: true,
      # The provisioned bots use seconds-long cooldowns, which is where this bites.
      cooldown_ms: 3000,
      capabilities: %{
        "greeter" => %{"greeting" => "Welcome {nickname}!", "enabled" => true},
        "custom_commands" => %{"enabled" => true}
      },
      channel_configs: [%{channel_name: "#greettest", enabled: true, capability_overrides: %{}}],
      custom_commands: [%{trigger: "tour", response: "Seven rooms, no filler.", enabled: true}]
    }

    setup do
      {:ok, pid} = RetroHexChat.Channels.Supervisor.start_child("#greettest")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#greettest")

      on_exit(fn ->
        Supervisor.stop_bot("GreetCooldownBot")
        if Process.alive?(pid), do: RetroHexChat.Channels.Supervisor.stop_child(pid)
      end)

      :ok
    end

    defp await_bot_line(text) do
      assert_receive %{event: "new_message", payload: %{author: "GreetCooldownBot", content: c}},
                     2000

      if String.contains?(c, text), do: :ok, else: await_bot_line(text)
    end

    test "answers the command that follows its own greeting" do
      {:ok, _pid} = Supervisor.start_bot(@greeter_bot)

      # The newcomer arrives and is greeted.
      {:ok, _} = RetroHexChat.Channels.Server.join("#greettest", "newcomer")
      await_bot_line("Welcome newcomer!")

      # ...and immediately asks the bot something, as people do. A greeting is
      # not a reply to anything, so it must not have started the cooldown.
      {:ok, _} = RetroHexChat.Channels.Server.send_message("#greettest", "newcomer", "!tour")
      await_bot_line("Seven rooms, no filler.")
    end
  end

  describe "a command addressed to the bot beats its mention response" do
    @command_bot %{
      id: 992,
      name: "OrderBot",
      nickname: "OrderBot",
      command_prefix: "!",
      created_by: "admin",
      enabled: true,
      cooldown_ms: 0,
      capabilities: %{
        "mention" => %{"response" => "Try !help for my commands.", "enabled" => true},
        "trivia" => %{"category" => "general", "enabled" => true},
        "dice" => %{"default_notation" => "1d20", "enabled" => true},
        "custom_commands" => %{"enabled" => true}
      },
      channel_configs: [%{channel_name: "#ordertest", enabled: true, capability_overrides: %{}}],
      custom_commands: []
    }

    setup do
      {:ok, pid} = RetroHexChat.Channels.Supervisor.start_child("#ordertest")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#ordertest")

      on_exit(fn ->
        Supervisor.stop_bot("OrderBot")
        if Process.alive?(pid), do: RetroHexChat.Channels.Supervisor.stop_child(pid)
      end)

      :ok
    end

    defp await_order_bot_line(match) do
      assert_receive %{event: "new_message", payload: %{author: "OrderBot", content: c}}, 2000
      if String.contains?(c, match), do: :ok, else: await_order_bot_line(match)
    end

    test "dice answers !OrderBot roll, not the mention fallback" do
      {:ok, _} = Supervisor.start_bot(@command_bot)
      {:ok, _} = RetroHexChat.Channels.Server.join("#ordertest", "player")

      {:ok, _} =
        RetroHexChat.Channels.Server.send_message("#ordertest", "player", "!OrderBot roll 1d20")

      await_order_bot_line("Rolling 1d20")
    end

    test "trivia answers !OrderBot trivia start, not the mention fallback" do
      {:ok, _} = Supervisor.start_bot(@command_bot)
      {:ok, _} = RetroHexChat.Channels.Server.join("#ordertest", "player")

      {:ok, _} =
        RetroHexChat.Channels.Server.send_message(
          "#ordertest",
          "player",
          "!OrderBot trivia start"
        )

      await_order_bot_line("Trivia started!")
    end

    test "the mention response still answers plain talk about the bot" do
      {:ok, _} = Supervisor.start_bot(@command_bot)
      {:ok, _} = RetroHexChat.Channels.Server.join("#ordertest", "player")

      {:ok, _} =
        RetroHexChat.Channels.Server.send_message("#ordertest", "player", "does OrderBot work?")

      await_order_bot_line("Try !help for my commands.")
    end
  end

  describe "durable capability state" do
    alias RetroHexChat.Bots.Queries

    setup do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "DurableBot",
          nickname: "DurableBot",
          created_by: "admin",
          capabilities: %{"rss" => %{"enabled" => true, "feeds" => []}}
        })

      on_exit(fn -> Supervisor.stop_bot("DurableBot") end)
      {:ok, bot: bot}
    end

    test "a feed added at runtime is still there after the process dies", %{bot: bot} do
      {:ok, pid} =
        Supervisor.start_bot(%{
          id: bot.id,
          name: bot.name,
          nickname: bot.nickname,
          command_prefix: "!",
          created_by: "admin",
          enabled: true,
          cooldown_ms: 0,
          capabilities: bot.capabilities,
          channel_configs: [],
          custom_commands: []
        })

      :sys.replace_state(pid, fn s ->
        feeds = [%{"id" => "f1", "url" => "https://example.com/feed.xml", "channel" => "#news"}]
        update_in(s.capability_states, &Map.put(&1, :rss, %{feeds: feeds, poll_interval_ms: 1}))
      end)

      # Reach the persistence path the same way a poll does.
      send(pid, {:capability_timer, :rss, %{type: :noop}})
      Process.sleep(50)

      stored = Queries.get_bot(bot.id).capabilities

      assert [%{"id" => "f1", "url" => "https://example.com/feed.xml"}] =
               get_in(stored, ["rss", "feeds"]),
             "the feed an operator typed must outlive the process that held it"
    end
  end

  describe "a feed added at runtime gets polled" do
    @rss_bot %{
      id: 991,
      name: "FeedTimerBot",
      nickname: "FeedTimerBot",
      command_prefix: "!",
      created_by: "admin",
      enabled: true,
      cooldown_ms: 0,
      capabilities: %{"rss" => %{"enabled" => true, "feeds" => []}},
      channel_configs: [%{channel_name: "#feedtest", enabled: true, capability_overrides: %{}}],
      custom_commands: []
    }

    setup do
      {:ok, chan} = RetroHexChat.Channels.Supervisor.start_child("#feedtest")
      # First human in owns the room, which is the standing the command requires.
      {:ok, _} = RetroHexChat.Channels.Server.join("#feedtest", "operator")

      on_exit(fn ->
        Supervisor.stop_bot("FeedTimerBot")
        if Process.alive?(chan), do: RetroHexChat.Channels.Supervisor.stop_child(chan)
      end)

      :ok
    end

    test "adding a feed schedules its poll" do
      {:ok, pid} = Supervisor.start_bot(@rss_bot)

      assert :sys.get_state(pid).capability_timers == %{},
             "nothing to poll before a feed exists"

      send(pid, %{
        event: "new_message",
        payload: %{
          id: 1,
          channel: "#feedtest",
          author: "operator",
          content: "!FeedTimerBot rss add https://93.184.216.34/feed.xml #feedtest",
          type: :message,
          timestamp: DateTime.utc_now(),
          reply_to_id: nil,
          reply_to_author: nil,
          reply_to_preview: nil
        }
      })

      Process.sleep(80)
      timers = :sys.get_state(pid).capability_timers

      assert map_size(timers) == 1,
             "a feed nobody polls is a feed that never publishes"

      assert [{:rss, %{type: :poll}}] = Map.values(timers)
    end
  end
end
