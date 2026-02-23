defmodule RetroHexChat.Bots.Capabilities.SchedulerTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Scheduler

  @default_config Scheduler.default_config()

  @ctx %{
    bot_nickname: "SchedBot",
    bot_name: "SchedBot",
    channel: "#general",
    command_prefix: "!",
    config: @default_config,
    capability_state: Scheduler.init_state(@default_config)
  }

  describe "name/0" do
    test "returns :scheduler" do
      assert Scheduler.name() == :scheduler
    end
  end

  describe "description/0" do
    test "does not say Coming soon" do
      refute Scheduler.description() =~ "Coming soon"
    end
  end

  describe "init_state/1" do
    test "initializes empty schedules from config" do
      state = Scheduler.init_state(@default_config)
      assert state.schedules == []
    end

    test "loads existing schedules from config" do
      config =
        Map.put(@default_config, "schedules", [
          %{
            "id" => "s1",
            "type" => "interval",
            "interval_min" => 30,
            "channel" => "#test",
            "message" => "hi"
          }
        ])

      state = Scheduler.init_state(config)
      assert length(state.schedules) == 1
    end
  end

  describe "schedule add interval" do
    test "adds interval schedule" do
      result =
        Scheduler.handle_message(
          "!SchedBot schedule add interval 30 #general Take a break!",
          "admin",
          @ctx
        )

      assert {:reply, text, new_state} = result
      assert text =~ "added"
      assert text =~ "30min"
      assert length(new_state.schedules) == 1
      assert hd(new_state.schedules)["type"] == "interval"
    end

    test "rejects interval below minimum" do
      result =
        Scheduler.handle_message("!SchedBot schedule add interval 2 #general hi", "admin", @ctx)

      assert {:reply, text} = result
      assert text =~ "Minimum interval"
    end

    test "rejects when max schedules reached" do
      state = %{schedules: Enum.map(1..10, fn i -> %{"id" => "s#{i}"} end)}
      ctx = %{@ctx | capability_state: state}

      result =
        Scheduler.handle_message("!SchedBot schedule add interval 30 #general hi", "admin", ctx)

      assert {:reply, text} = result
      assert text =~ "Maximum"
    end
  end

  describe "schedule add daily" do
    test "adds daily schedule" do
      result =
        Scheduler.handle_message(
          "!SchedBot schedule add daily 09:00 #general Good morning!",
          "admin",
          @ctx
        )

      assert {:reply, text, new_state} = result
      assert text =~ "added"
      assert text =~ "09:00 UTC"
      assert length(new_state.schedules) == 1
      assert hd(new_state.schedules)["type"] == "daily"
    end

    test "rejects invalid time format" do
      result =
        Scheduler.handle_message("!SchedBot schedule add daily 25:00 #general hi", "admin", @ctx)

      assert {:reply, text} = result
      assert text =~ "Invalid time"
    end
  end

  describe "schedule list" do
    test "shows empty list" do
      result = Scheduler.handle_message("!SchedBot schedule list", "admin", @ctx)
      assert {:reply, text} = result
      assert text =~ "No active schedules"
    end

    test "shows schedules" do
      state = %{
        schedules: [
          %{
            "id" => "s1",
            "type" => "interval",
            "interval_min" => 30,
            "channel" => "#general",
            "message" => "Break!"
          }
        ]
      }

      ctx = %{@ctx | capability_state: state}
      result = Scheduler.handle_message("!SchedBot schedule list", "admin", ctx)
      assert {:multi_reply, lines} = result
      assert length(lines) >= 2
    end
  end

  describe "schedule remove" do
    test "removes existing schedule" do
      state = %{
        schedules: [
          %{
            "id" => "s1",
            "type" => "interval",
            "interval_min" => 30,
            "channel" => "#general",
            "message" => "hi"
          }
        ]
      }

      ctx = %{@ctx | capability_state: state}
      result = Scheduler.handle_message("!SchedBot schedule remove s1", "admin", ctx)
      assert {:reply, text, new_state} = result
      assert text =~ "removed"
      assert new_state.schedules == []
    end

    test "reports not found" do
      result = Scheduler.handle_message("!SchedBot schedule remove nonexistent", "admin", @ctx)
      assert {:reply, text} = result
      assert text =~ "not found"
    end
  end

  describe "handle_timer/3" do
    test "fires scheduled message" do
      state = %{
        schedules: [
          %{
            "id" => "s1",
            "type" => "interval",
            "interval_min" => 30,
            "channel" => "#general",
            "message" => "Reminder!",
            "last_fired" => nil
          }
        ]
      }

      payload = %{schedule_id: "s1", channel: "#general"}
      {result, new_state} = Scheduler.handle_timer(payload, state, @ctx)
      assert {:reply, "Reminder!"} = result
      # Check last_fired was updated
      sched = hd(new_state.schedules)
      assert sched["last_fired"] != nil
    end

    test "ignores unknown schedule_id" do
      state = %{schedules: []}
      payload = %{schedule_id: "nonexistent", channel: "#general"}
      {result, _state} = Scheduler.handle_timer(payload, state, @ctx)
      assert :ignore == result
    end
  end

  describe "calculate_next_delay/1" do
    test "interval returns minutes in ms" do
      assert Scheduler.calculate_next_delay(%{"type" => "interval", "interval_min" => 5}) ==
               300_000
    end

    test "daily returns positive delay" do
      delay = Scheduler.calculate_next_delay(%{"type" => "daily", "time" => "00:00"})
      assert is_integer(delay)
      assert delay > 0
    end
  end

  describe "commands/0" do
    test "returns schedule commands" do
      cmds = Scheduler.commands()
      triggers = Enum.map(cmds, & &1.trigger)
      assert "schedule add" in triggers
      assert "schedule list" in triggers
      assert "schedule remove" in triggers
    end
  end

  describe "reschedule_delay/2" do
    test "returns interval delay for existing schedule" do
      state = %{
        schedules: [
          %{
            "id" => "s1",
            "type" => "interval",
            "interval_min" => 10,
            "channel" => "#general",
            "message" => "hi"
          }
        ]
      }

      payload = %{schedule_id: "s1", channel: "#general"}
      assert {:reschedule, 600_000, ^payload} = Scheduler.reschedule_delay(payload, state)
    end

    test "returns :no_reschedule for unknown schedule_id" do
      state = %{schedules: []}
      payload = %{schedule_id: "nonexistent", channel: "#general"}
      assert :no_reschedule == Scheduler.reschedule_delay(payload, state)
    end

    test "returns correct daily delay (positive, <86400000ms)" do
      state = %{
        schedules: [
          %{
            "id" => "s1",
            "type" => "daily",
            "time" => "00:00",
            "channel" => "#general",
            "message" => "Good morning!"
          }
        ]
      }

      payload = %{schedule_id: "s1", channel: "#general"}
      assert {:reschedule, delay, ^payload} = Scheduler.reschedule_delay(payload, state)
      assert delay > 0
      assert delay <= 86_400_000
    end

    test "returns :no_reschedule when schedules list is empty" do
      state = %{schedules: []}
      payload = %{schedule_id: "s1", channel: "#general"}
      assert :no_reschedule == Scheduler.reschedule_delay(payload, state)
    end
  end

  describe "ignores unrelated messages" do
    test "ignores non-schedule messages" do
      assert :ignore == Scheduler.handle_message("hello", "user", @ctx)
    end
  end
end
