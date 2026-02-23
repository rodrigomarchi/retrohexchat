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
end
