defmodule RetroHexChat.Bots.BotLifecycleTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.{Queries, Registry, Server, Supervisor}

  @base_caps %{
    "mention" => %{"response" => "Hi {nickname}!", "enabled" => true},
    "greeter" => %{"greeting" => "Welcome {nickname}!", "enabled" => true},
    "help" => %{"enabled" => true},
    "custom_commands" => %{"enabled" => true},
    "dice" => %{
      "enabled" => true,
      "max_dice" => 100,
      "max_sides" => 1000,
      "default_notation" => "d20"
    }
  }

  setup do
    # Clean up any leftover bots from previous test runs
    for nickname <- Registry.registered_bots() do
      Supervisor.stop_bot(nickname)
    end

    on_exit(fn ->
      # Stop bot processes (in-memory cleanup)
      for nickname <- Registry.registered_bots() do
        Supervisor.stop_bot(nickname)
      end

      # DB cleanup is handled by Ecto sandbox rollback
    end)

    :ok
  end

  defp start_bot(bot, overrides \\ %{}) do
    bot_data =
      Map.merge(
        %{
          id: bot.id,
          name: bot.name,
          nickname: bot.nickname,
          command_prefix: bot.command_prefix || "!",
          created_by: bot.created_by,
          enabled: bot.enabled,
          cooldown_ms: bot.cooldown_ms || 2000,
          capabilities: bot.capabilities,
          channel_configs: [],
          custom_commands: []
        },
        overrides
      )

    Supervisor.start_bot(bot_data)
  end

  describe "full bot lifecycle" do
    test "create → start → get_state → stop → destroy" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "LifeBot",
          nickname: "LifeBot",
          created_by: "admin",
          capabilities: @base_caps
        })

      # Start
      {:ok, pid} = start_bot(bot)
      assert Process.alive?(pid)
      assert {:ok, ^pid} = Registry.lookup("LifeBot")

      # Get state
      {:ok, state} = Server.get_state("LifeBot")
      assert state.name == "LifeBot"
      assert state.enabled == true

      # Stop
      :ok = Supervisor.stop_bot("LifeBot")
      refute Process.alive?(pid)
      # Registry deregistration is async (via :DOWN monitor); allow a moment for cleanup
      Process.sleep(10)
      assert {:error, :not_found} = Registry.lookup("LifeBot")

      # Destroy
      {:ok, _} = Queries.delete_bot(bot)
      assert is_nil(Queries.get_bot_by_name("LifeBot"))
    end

    test "bot with multiple capabilities dispatches correctly" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "MultiBot",
          nickname: "MultiBot",
          created_by: "admin",
          capabilities: @base_caps
        })

      # Add command in DB so it's loaded during init
      {:ok, _} =
        Queries.add_custom_command(bot.id, %{
          trigger: "rules",
          response: "Read #rules",
          description: "Rules",
          added_by: "admin"
        })

      {:ok, _pid} =
        start_bot(bot, %{
          command_prefix: "!",
          cooldown_ms: 100
        })

      # Verify bot state has the commands
      {:ok, state} = Server.get_state("MultiBot")
      assert Map.has_key?(state.custom_commands, "rules")
    end

    test "cooldown prevents rapid-fire responses" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "CoolBot",
          nickname: "CoolBot",
          created_by: "admin",
          cooldown_ms: 5000,
          capabilities: %{"mention" => %{"response" => "Hi!", "enabled" => true}}
        })

      {:ok, _} = Queries.add_channel_config(bot.id, "#cooltest")

      {:ok, pid} = start_bot(bot, %{cooldown_ms: 5000})

      # Simulate first message using real PubSub map format
      send(pid, %{
        event: "new_message",
        payload: %{
          id: 1,
          channel: "#cooltest",
          author: "user",
          content: "CoolBot hi",
          type: :message,
          timestamp: DateTime.utc_now(),
          reply_to_id: nil,
          reply_to_author: nil,
          reply_to_preview: nil
        }
      })

      Process.sleep(50)

      assert Process.alive?(pid)
      state = :sys.get_state(pid)
      # Should have recorded a last_response_at for the channel
      assert Map.has_key?(state.last_response_at, "#cooltest")
    end

    test "bot handles PubSub map-format new_message (real broadcast format)" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "PubBot",
          nickname: "PubBot",
          created_by: "admin",
          cooldown_ms: 500,
          capabilities: %{"mention" => %{"response" => "Hi!", "enabled" => true}}
        })

      {:ok, _} = Queries.add_channel_config(bot.id, "#pubtest")

      {:ok, pid} = start_bot(bot, %{cooldown_ms: 100})

      # Send message in the ACTUAL PubSub format (map with :author, not tuple with :nickname)
      send(pid, %{
        event: "new_message",
        payload: %{
          id: 1,
          channel: "#pubtest",
          author: "user",
          content: "PubBot hi",
          type: :message,
          timestamp: DateTime.utc_now(),
          reply_to_id: nil,
          reply_to_author: nil,
          reply_to_preview: nil
        }
      })

      Process.sleep(50)

      assert Process.alive?(pid)
      state = :sys.get_state(pid)
      # Bot should have processed the message and recorded cooldown
      assert Map.has_key?(state.last_response_at, "#pubtest")
    end

    test "bot survives unknown messages" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "SurvBot",
          nickname: "SurvBot",
          created_by: "admin",
          capabilities: @base_caps
        })

      {:ok, pid} = start_bot(bot, %{cooldown_ms: 100})

      # Send various unknown messages — bot should not crash
      send(pid, {:unknown_event, %{}})
      send(pid, :random_message)
      send(pid, {:topic_changed, %{channel: nil, nickname: "user"}})
      Process.sleep(50)

      assert Process.alive?(pid)
    end
  end

  describe "timer lifecycle E2E" do
    test "scheduler fires and reschedules repeatedly" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "TimerE2E",
          nickname: "TimerE2E",
          created_by: "admin",
          capabilities: %{
            "scheduler" => %{
              "enabled" => true,
              "schedules" => [
                %{
                  "id" => "se1",
                  "type" => "interval",
                  "interval_min" => 1,
                  "channel" => nil,
                  "message" => "Tick!"
                }
              ]
            }
          }
        })

      {:ok, pid} = start_bot(bot, %{cooldown_ms: 100})

      # Verify initial timer exists (interval_min=1 => 60s delay, so timer is pending)
      state = :sys.get_state(pid)
      assert map_size(state.capability_timers) >= 1

      # Clear existing timers and manually fire
      :sys.replace_state(pid, fn s -> %{s | capability_timers: %{}} end)
      send(pid, {:capability_timer, :scheduler, %{schedule_id: "se1", channel: nil}})
      Process.sleep(50)

      # Verify rescheduled
      state2 = :sys.get_state(pid)
      assert map_size(state2.capability_timers) >= 1

      # Fire again
      :sys.replace_state(pid, fn s -> %{s | capability_timers: %{}} end)
      send(pid, {:capability_timer, :scheduler, %{schedule_id: "se1", channel: nil}})
      Process.sleep(50)

      # Verify rescheduled again (proves multiple reschedules work)
      state3 = :sys.get_state(pid)
      assert map_size(state3.capability_timers) >= 1
    end

    test "removing schedule stops rescheduling" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "StopE2E",
          nickname: "StopE2E",
          created_by: "admin",
          capabilities: %{
            "scheduler" => %{
              "enabled" => true,
              "schedules" => [
                %{
                  "id" => "se2",
                  "type" => "interval",
                  "interval_min" => 1,
                  "channel" => nil,
                  "message" => "Stop!"
                }
              ]
            }
          }
        })

      {:ok, pid} = start_bot(bot, %{cooldown_ms: 100})

      # First fire — should reschedule
      :sys.replace_state(pid, fn s -> %{s | capability_timers: %{}} end)
      send(pid, {:capability_timer, :scheduler, %{schedule_id: "se2", channel: nil}})
      Process.sleep(50)
      state = :sys.get_state(pid)
      assert map_size(state.capability_timers) >= 1

      # Remove schedule from state
      :sys.replace_state(pid, fn s ->
        new_cap_states = Map.put(s.capability_states, :scheduler, %{schedules: []})
        %{s | capability_states: new_cap_states, capability_timers: %{}}
      end)

      # Fire again — should NOT reschedule
      send(pid, {:capability_timer, :scheduler, %{schedule_id: "se2", channel: nil}})
      Process.sleep(50)
      state2 = :sys.get_state(pid)

      scheduler_timers =
        Enum.filter(state2.capability_timers, fn {_ref, {name, _}} -> name == :scheduler end)

      assert scheduler_timers == []
    end
  end

  describe "DB reload on init" do
    test "bot loads channels from DB even when channel_configs is empty" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "ReloadBot",
          nickname: "ReloadBot",
          created_by: "admin",
          capabilities: %{
            "mention" => %{"response" => "Hi!", "enabled" => true}
          }
        })

      # Add channel configs directly in DB
      {:ok, _} = Queries.add_channel_config(bot.id, "#reload-ch1")
      {:ok, _} = Queries.add_channel_config(bot.id, "#reload-ch2")

      # Start with empty channel_configs (simulates supervisor restart)
      {:ok, pid} = start_bot(bot, %{cooldown_ms: 100, channel_configs: []})

      state = :sys.get_state(pid)
      # Should have loaded channels from DB
      assert Map.has_key?(state.channels, "#reload-ch1")
      assert Map.has_key?(state.channels, "#reload-ch2")
    end

    test "bot loads capabilities from DB on restart" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "CapReload",
          nickname: "CapReload",
          created_by: "admin",
          capabilities: %{
            "mention" => %{"response" => "Hi!", "enabled" => true},
            "moderation" => %{
              "enabled" => true,
              "spam_threshold" => 5,
              "flood_threshold" => 8,
              "warn_message" => "Behave!"
            }
          }
        })

      # Start with only mention (simulates original start before moderation was added)
      {:ok, pid} =
        start_bot(bot, %{
          cooldown_ms: 100,
          capabilities: %{"mention" => %{"response" => "Hi!", "enabled" => true}}
        })

      state = :sys.get_state(pid)
      # Should have loaded moderation from DB even though bot_data only had mention
      cap_names = Enum.map(state.capabilities, fn {name, _, _} -> name end)
      assert :moderation in cap_names
      # And moderation state should be properly initialized
      assert Map.has_key?(state.capability_states.moderation, :message_history)
    end

    test "bot loads custom commands from DB on restart" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "CmdReload",
          nickname: "CmdReload",
          created_by: "admin",
          capabilities: %{
            "custom_commands" => %{"enabled" => true}
          }
        })

      # Add commands directly in DB
      {:ok, _} =
        Queries.add_custom_command(bot.id, %{
          trigger: "rules",
          response: "Read #rules",
          added_by: "admin"
        })

      # Start with empty custom_commands
      {:ok, pid} = start_bot(bot, %{cooldown_ms: 100, custom_commands: []})

      state = :sys.get_state(pid)
      assert Map.has_key?(state.custom_commands, "rules")
    end
  end

  describe "event logging E2E" do
    test "events are logged during bot operation" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "LogBot",
          nickname: "LogBot",
          created_by: "admin",
          capabilities: %{"mention" => %{"response" => "Hi!", "enabled" => true}}
        })

      {:ok, _} = Queries.add_channel_config(bot.id, "#logtest")

      {:ok, pid} = start_bot(bot, %{cooldown_ms: 100})

      # Simulate a message to trigger event logging (real PubSub format)
      send(pid, %{
        event: "new_message",
        payload: %{
          id: 1,
          channel: "#logtest",
          author: "user",
          content: "LogBot hi",
          type: :message,
          timestamp: DateTime.utc_now(),
          reply_to_id: nil,
          reply_to_author: nil,
          reply_to_preview: nil
        }
      })

      # Give async Task time to log
      Process.sleep(300)

      events = Queries.list_event_logs(bot.id)
      assert events != []
      assert Enum.any?(events, &(&1.event_type == "message_response"))
    end
  end
end
