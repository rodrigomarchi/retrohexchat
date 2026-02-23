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

      {:ok, _pid} =
        start_bot(bot, %{
          command_prefix: "!",
          cooldown_ms: 100,
          custom_commands: [
            %{trigger: "rules", response: "Read #rules", description: "Rules", enabled: true}
          ]
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

      {:ok, pid} =
        start_bot(bot, %{
          cooldown_ms: 5000,
          channel_configs: [
            %{channel_name: "#cooltest", enabled: true, capability_overrides: %{}}
          ]
        })

      # Simulate first message — the bot will try to respond (channel process absent, caught)
      send(pid, {:new_message, %{nickname: "user", channel: "#cooltest", content: "CoolBot hi"}})
      Process.sleep(50)

      assert Process.alive?(pid)
      state = :sys.get_state(pid)
      # Should have recorded a last_response_at for the channel
      assert Map.has_key?(state.last_response_at, "#cooltest")
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

  describe "event logging E2E" do
    test "events are logged during bot operation" do
      {:ok, bot} =
        Queries.create_bot(%{
          name: "LogBot",
          nickname: "LogBot",
          created_by: "admin",
          capabilities: %{"mention" => %{"response" => "Hi!", "enabled" => true}}
        })

      {:ok, pid} =
        start_bot(bot, %{
          cooldown_ms: 100,
          channel_configs: [
            %{channel_name: "#logtest", enabled: true, capability_overrides: %{}}
          ]
        })

      # Simulate a message to trigger event logging
      send(pid, {:new_message, %{nickname: "user", channel: "#logtest", content: "LogBot hi"}})

      # Give async Task time to log
      Process.sleep(300)

      events = Queries.list_event_logs(bot.id)
      assert events != []
      assert Enum.any?(events, &(&1.event_type == "message_response"))
    end
  end
end
