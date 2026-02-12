defmodule RetroHexChat.Commands.Handlers.TimerTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Timer

  @context %{
    nickname: "Test",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty string (bare /timer)" do
      assert :ok = Timer.validate("")
    end

    test "accepts list" do
      assert :ok = Timer.validate("list")
    end

    test "accepts stop with name" do
      assert :ok = Timer.validate("stop myname")
    end

    test "accepts one-shot timer args" do
      assert :ok = Timer.validate("remind 60 /me hi")
    end

    test "accepts repeat timer args" do
      assert :ok = Timer.validate("hb repeat 30 /me alive")
    end
  end

  describe "execute/2" do
    test "bare /timer shows help" do
      assert {:ok, :system, %{content: content}} = Timer.execute([], @context)
      assert content =~ "/timer"
    end

    test "list returns timer_list ui_action" do
      assert {:ok, :ui_action, :timer_list, %{}} = Timer.execute(["list"], @context)
    end

    test "stop returns timer_stop with name" do
      assert {:ok, :ui_action, :timer_stop, %{name: "hb"}} =
               Timer.execute(["stop", "hb"], @context)
    end

    test "one-shot timer returns timer_create" do
      assert {:ok, :ui_action, :timer_create,
              %{name: "remind", type: :once, interval: 60, command: "/me hi"}} =
               Timer.execute(["remind", "60", "/me", "hi"], @context)
    end

    test "repeat timer returns timer_create" do
      assert {:ok, :ui_action, :timer_create,
              %{name: "hb", type: :repeat, interval: 30, command: "/me alive"}} =
               Timer.execute(["hb", "repeat", "30", "/me", "alive"], @context)
    end

    test "invalid args returns error" do
      assert {:error, _} = Timer.execute(["test", "abc"], @context)
    end
  end

  describe "help/0" do
    test "returns help map with correct name" do
      help = Timer.help()
      assert help.name == "timer"
    end

    test "returns help map with syntax" do
      help = Timer.help()
      assert is_binary(help.syntax)
      assert help.syntax =~ "/timer"
    end

    test "returns help map with examples" do
      help = Timer.help()
      assert [_ | _] = help.examples
    end
  end
end
