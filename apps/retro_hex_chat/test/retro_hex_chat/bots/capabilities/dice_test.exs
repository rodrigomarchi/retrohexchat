defmodule RetroHexChat.Bots.Capabilities.DiceTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Dice

  @ctx %{
    bot_nickname: "DiceBot",
    bot_name: "DiceBot",
    channel: "#test",
    command_prefix: "!",
    config: Dice.default_config(),
    capability_state: %{}
  }

  describe "name/0" do
    test "returns :dice" do
      assert Dice.name() == :dice
    end
  end

  describe "description/0" do
    test "returns description without 'Coming soon'" do
      desc = Dice.description()
      assert is_binary(desc)
      refute desc =~ "Coming soon"
    end
  end

  describe "parse_notation/1" do
    test "parses simple NdS" do
      assert {:ok, %{count: 2, sides: 6, modifier: 0, keep: nil}} = Dice.parse_notation("2d6")
    end

    test "parses dS (defaults to 1 die)" do
      assert {:ok, %{count: 1, sides: 20, modifier: 0, keep: nil}} = Dice.parse_notation("d20")
    end

    test "parses NdS+M" do
      assert {:ok, %{count: 1, sides: 20, modifier: 5, keep: nil}} =
               Dice.parse_notation("1d20+5")
    end

    test "parses NdS-M" do
      assert {:ok, %{count: 1, sides: 8, modifier: -2, keep: nil}} =
               Dice.parse_notation("1d8-2")
    end

    test "parses NdSkhN (keep highest)" do
      assert {:ok, %{count: 4, sides: 6, modifier: 0, keep: {:high, 3}}} =
               Dice.parse_notation("4d6kh3")
    end

    test "parses NdSklN (keep lowest)" do
      assert {:ok, %{count: 4, sides: 6, modifier: 0, keep: {:low, 1}}} =
               Dice.parse_notation("4d6kl1")
    end

    test "parses NdSkhN+M (keep highest with modifier)" do
      assert {:ok, %{count: 4, sides: 6, modifier: 2, keep: {:high, 3}}} =
               Dice.parse_notation("4d6kh3+2")
    end

    test "rejects invalid notation" do
      assert {:error, _} = Dice.parse_notation("abc")
    end

    test "rejects keep count > dice count" do
      assert {:error, msg} = Dice.parse_notation("2d6kh3")
      assert msg =~ "Cannot keep 3"
    end
  end

  describe "handle_message/3 — roll command" do
    test "responds to roll command" do
      result = Dice.handle_message("!DiceBot roll 2d6", "user", @ctx)
      assert {:reply, text} = result
      assert text =~ "Rolling 2d6:"
    end

    test "responds to dice command (alias)" do
      result = Dice.handle_message("!DiceBot dice d20", "user", @ctx)
      assert {:reply, text} = result
      assert text =~ "Rolling d20:"
    end

    test "uses default notation when no notation given" do
      result = Dice.handle_message("!DiceBot roll", "user", @ctx)
      assert {:reply, text} = result
      assert text =~ "Rolling d20:"
    end

    test "rejects exceeding max_dice" do
      config = Map.put(@ctx.config, "max_dice", 10)
      ctx = %{@ctx | config: config}
      result = Dice.handle_message("!DiceBot roll 20d6", "user", ctx)
      assert {:reply, text} = result
      assert text =~ "Maximum 10 dice"
    end

    test "rejects exceeding max_sides" do
      config = Map.put(@ctx.config, "max_sides", 100)
      ctx = %{@ctx | config: config}
      result = Dice.handle_message("!DiceBot roll d200", "user", ctx)
      assert {:reply, text} = result
      assert text =~ "Maximum 100 sides"
    end

    test "ignores unrelated messages" do
      assert :ignore == Dice.handle_message("hello world", "user", @ctx)
    end

    test "ignores messages for other bots" do
      assert :ignore == Dice.handle_message("!OtherBot roll d20", "user", @ctx)
    end

    test "is case insensitive for command matching" do
      result = Dice.handle_message("!dicebot ROLL 2d6", "user", @ctx)
      assert {:reply, _} = result
    end
  end

  describe "handle_message/3 — result format" do
    test "simple roll shows sum" do
      # Seed for deterministic test
      :rand.seed(:exsss, {1, 2, 3})
      result = Dice.handle_message("!DiceBot roll 1d6", "user", @ctx)
      assert {:reply, text} = result
      assert text =~ "Rolling 1d6:"
      assert text =~ "="
    end

    test "modifier roll shows modifier in output" do
      result = Dice.handle_message("!DiceBot roll 1d20+5", "user", @ctx)
      assert {:reply, text} = result
      assert text =~ "+5"
      assert text =~ "Rolling 1d20+5:"
    end

    test "keep highest shows kept dice" do
      result = Dice.handle_message("!DiceBot roll 4d6kh3", "user", @ctx)
      assert {:reply, text} = result
      assert text =~ "keeping"
    end

    test "keep lowest shows kept dice" do
      result = Dice.handle_message("!DiceBot roll 4d6kl1", "user", @ctx)
      assert {:reply, text} = result
      assert text =~ "keeping"
    end
  end

  describe "handle_event/3" do
    test "always returns :ignore" do
      assert :ignore == Dice.handle_event(:user_joined, %{}, @ctx)
    end
  end

  describe "validate_config/1" do
    test "accepts valid config" do
      assert :ok == Dice.validate_config(Dice.default_config())
    end

    test "rejects invalid max_dice" do
      assert {:error, _} = Dice.validate_config(%{"max_dice" => 0})
    end

    test "rejects invalid max_sides" do
      assert {:error, _} = Dice.validate_config(%{"max_sides" => 1})
    end
  end

  describe "commands/0" do
    test "returns roll and dice commands" do
      cmds = Dice.commands()
      assert length(cmds) == 2
      triggers = Enum.map(cmds, & &1.trigger)
      assert "roll" in triggers
      assert "dice" in triggers
    end
  end
end
