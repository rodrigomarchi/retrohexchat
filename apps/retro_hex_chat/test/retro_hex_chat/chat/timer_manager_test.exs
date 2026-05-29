defmodule RetroHexChat.Chat.TimerManagerTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.TimerManager

  describe "parse_timer_args/1" do
    test "parses one-shot timer" do
      assert {:ok,
              %{action: :create, name: "remind", type: :once, interval: 60, command: "/me hi"}} =
               TimerManager.parse_timer_args(["remind", "60", "/me", "hi"])
    end

    test "parses repeat timer" do
      assert {:ok,
              %{action: :create, name: "hb", type: :repeat, interval: 30, command: "/me alive"}} =
               TimerManager.parse_timer_args(["hb", "repeat", "30", "/me", "alive"])
    end

    test "parses list command" do
      assert {:ok, %{action: :list}} = TimerManager.parse_timer_args(["list"])
    end

    test "parses stop command" do
      assert {:ok, %{action: :stop, name: "hb"}} = TimerManager.parse_timer_args(["stop", "hb"])
    end

    test "returns error for empty args" do
      assert {:error, _} = TimerManager.parse_timer_args([])
    end

    test "returns error for invalid interval" do
      assert {:error, _} = TimerManager.parse_timer_args(["test", "abc", "/me", "test"])
    end

    test "returns error for missing command in one-shot" do
      assert {:error, _} = TimerManager.parse_timer_args(["test", "60"])
    end

    test "returns error for missing command in repeat" do
      assert {:error, _} = TimerManager.parse_timer_args(["test", "repeat", "60"])
    end

    test "returns error for stop without name" do
      assert {:error, _} = TimerManager.parse_timer_args(["stop"])
    end
  end

  describe "validate_create/5" do
    test "accepts valid one-shot timer" do
      assert :ok = TimerManager.validate_create(%{}, "test", :once, 60, "/me test")
    end

    test "accepts valid repeat timer" do
      assert :ok = TimerManager.validate_create(%{}, "test", :repeat, 30, "/me test")
    end

    test "rejects when at max timers (5)" do
      timers = Map.new(1..5, fn i -> {"timer#{i}", %{}} end)
      assert {:error, _} = TimerManager.validate_create(timers, "extra", :once, 60, "/me test")
    end

    test "allows replacing existing timer with same name" do
      timers = %{"test" => %{}}
      assert :ok = TimerManager.validate_create(timers, "test", :once, 60, "/me test")
    end

    test "rejects invalid name" do
      assert {:error, _} = TimerManager.validate_create(%{}, "my timer!", :once, 60, "/me test")
    end

    test "rejects empty name" do
      assert {:error, _} = TimerManager.validate_create(%{}, "", :once, 60, "/me test")
    end

    test "rejects interval below minimum (1 for once)" do
      assert {:error, _} = TimerManager.validate_create(%{}, "test", :once, 0, "/me test")
    end

    test "allows repeat interval below minimum so it can be clamped" do
      assert :ok = TimerManager.validate_create(%{}, "test", :repeat, 5, "/me test")
    end

    test "rejects interval above maximum (86400)" do
      assert {:error, _} = TimerManager.validate_create(%{}, "test", :once, 86_401, "/me test")
    end
  end

  describe "clamp_interval/2" do
    test "does not clamp valid one-shot interval" do
      assert {60, nil} = TimerManager.clamp_interval(:once, 60)
    end

    test "does not clamp valid repeat interval" do
      assert {30, nil} = TimerManager.clamp_interval(:repeat, 30)
    end

    test "clamps repeat below 10 to 10 with notice" do
      assert {10, notice} = TimerManager.clamp_interval(:repeat, 5)
      assert is_binary(notice)
      assert notice =~ "10"
    end

    test "does not clamp repeat at exactly 10" do
      assert {10, nil} = TimerManager.clamp_interval(:repeat, 10)
    end
  end

  describe "format_timer_list/1" do
    test "returns 'no active timers' for empty map" do
      result = TimerManager.format_timer_list(%{})
      assert result =~ "No active timers"
    end

    test "formats timers with name, type, interval, and command" do
      timers = %{
        "remind" => %{type: :once, interval: 60, command: "/me hi", ref: make_ref()}
      }

      result = TimerManager.format_timer_list(timers)
      assert result =~ "remind"
      assert result =~ "once"
      assert result =~ "60"
    end

    test "formats multiple timers" do
      timers = %{
        "a" => %{type: :once, interval: 10, command: "/me a", ref: make_ref()},
        "b" => %{type: :repeat, interval: 30, command: "/me b", ref: make_ref()}
      }

      result = TimerManager.format_timer_list(timers)
      assert result =~ "a"
      assert result =~ "b"
    end
  end
end
