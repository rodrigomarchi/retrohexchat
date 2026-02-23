defmodule RetroHexChat.Bots.Capabilities.ModerationTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Moderation

  @default_config Moderation.default_config()

  @ctx %{
    bot_nickname: "ModBot",
    bot_name: "ModBot",
    channel: "#test",
    command_prefix: "!",
    config: @default_config,
    capability_state: Moderation.init_state(@default_config)
  }

  describe "name/0" do
    test "returns :moderation" do
      assert Moderation.name() == :moderation
    end
  end

  describe "passive?/0" do
    test "is passive" do
      assert Moderation.passive?() == true
    end
  end

  describe "description/0" do
    test "returns description without 'Coming soon'" do
      refute Moderation.description() =~ "Coming soon"
    end
  end

  describe "init_state/1" do
    test "initializes with empty history and warnings" do
      state = Moderation.init_state(@default_config)
      assert state.message_history == %{}
      assert state.warnings == %{}
    end
  end

  describe "blocked words detection" do
    test "detects blocked word" do
      config = Map.put(@default_config, "blocked_words", ["badword"])
      ctx = %{@ctx | config: config}
      result = Moderation.handle_message("this has badword in it", "user1", ctx)
      assert {:reply, msg, _state} = result
      assert msg =~ "blocked words"
    end

    test "case insensitive matching" do
      config = Map.put(@default_config, "blocked_words", ["badword"])
      ctx = %{@ctx | config: config}
      result = Moderation.handle_message("THIS HAS BADWORD IN IT", "user1", ctx)
      assert {:reply, msg, _state} = result
      assert msg =~ "blocked words"
    end

    test "ignores clean messages" do
      config = Map.put(@default_config, "blocked_words", ["badword"])
      ctx = %{@ctx | config: config}
      result = Moderation.handle_message("this is a clean message", "user1", ctx)
      assert {:side_effect, %{state_update: _}} = result
    end
  end

  describe "spam detection" do
    test "detects repeated messages" do
      config = Map.merge(@default_config, %{"spam_threshold" => 3, "spam_window_sec" => 10})
      now = System.monotonic_time(:second)

      # Build state with 2 prior identical messages
      state = %{
        message_history: %{
          "spammer" => [
            {"same message", now},
            {"same message", now - 1}
          ]
        },
        warnings: %{}
      }

      ctx = %{@ctx | config: config, capability_state: state}
      result = Moderation.handle_message("same message", "spammer", ctx)
      assert {:reply, msg, _state} = result
      assert msg =~ "spamming"
    end

    test "does not flag different messages" do
      config = Map.merge(@default_config, %{"spam_threshold" => 3, "spam_window_sec" => 10})
      now = System.monotonic_time(:second)

      state = %{
        message_history: %{
          "user" => [
            {"message 1", now},
            {"message 2", now - 1}
          ]
        },
        warnings: %{}
      }

      ctx = %{@ctx | config: config, capability_state: state}
      result = Moderation.handle_message("message 3", "user", ctx)
      assert {:side_effect, %{state_update: _}} = result
    end
  end

  describe "flood detection" do
    test "detects flood" do
      config = Map.merge(@default_config, %{"flood_threshold" => 3, "flood_window_sec" => 5})
      now = System.monotonic_time(:second)

      state = %{
        message_history: %{
          "flooder" => [
            {"msg 1", now},
            {"msg 2", now - 1}
          ]
        },
        warnings: %{}
      }

      ctx = %{@ctx | config: config, capability_state: state}
      result = Moderation.handle_message("msg 3", "flooder", ctx)
      assert {:reply, msg, _state} = result
      assert msg =~ "flooding"
    end
  end

  describe "caps lock detection" do
    test "detects excessive caps" do
      config = Map.merge(@default_config, %{"caps_threshold" => 0.7, "caps_min_length" => 10})
      ctx = %{@ctx | config: config}
      result = Moderation.handle_message("THIS IS ALL CAPS LOCK ABUSE", "user1", ctx)
      assert {:reply, msg, _state} = result
      assert msg =~ "caps lock"
    end

    test "ignores short caps messages" do
      config = Map.merge(@default_config, %{"caps_threshold" => 0.7, "caps_min_length" => 10})
      ctx = %{@ctx | config: config}
      result = Moderation.handle_message("OK FINE", "user1", ctx)
      assert {:side_effect, %{state_update: _}} = result
    end

    test "ignores messages below caps threshold" do
      config = Map.merge(@default_config, %{"caps_threshold" => 0.7, "caps_min_length" => 10})
      ctx = %{@ctx | config: config}
      result = Moderation.handle_message("This is a normal message with some text", "user1", ctx)
      assert {:side_effect, %{state_update: _}} = result
    end
  end

  describe "warn message template" do
    test "substitutes nickname" do
      config =
        Map.merge(@default_config, %{
          "blocked_words" => ["badword"],
          "warn_message" => "Hey {nickname}, stop!"
        })

      ctx = %{@ctx | config: config}
      result = Moderation.handle_message("badword", "TestUser", ctx)
      assert {:reply, msg, _state} = result
      assert msg =~ "Hey TestUser, stop!"
    end

    test "tracks warning count" do
      config = Map.put(@default_config, "blocked_words", ["badword"])
      ctx = %{@ctx | config: config}
      {:reply, _, state1} = Moderation.handle_message("badword", "user1", ctx)
      assert state1.warnings["user1"] == 1

      ctx2 = %{ctx | capability_state: state1}
      {:reply, _, state2} = Moderation.handle_message("badword", "user1", ctx2)
      assert state2.warnings["user1"] == 2
    end
  end

  describe "disabled" do
    test "returns :ignore when disabled" do
      config = Map.put(@default_config, "enabled", false)
      ctx = %{@ctx | config: config}
      assert :ignore == Moderation.handle_message("badword", "user1", ctx)
    end
  end

  describe "validate_config/1" do
    test "accepts valid actions" do
      for action <- ["warn", "mute", "kick"] do
        assert :ok == Moderation.validate_config(%{"action" => action})
      end
    end

    test "rejects invalid action" do
      assert {:error, _} = Moderation.validate_config(%{"action" => "invalid"})
    end
  end

  describe "detect_violation/5" do
    test "returns nil for clean message" do
      now = System.monotonic_time(:second)
      state = Moderation.init_state(@default_config)
      assert nil == Moderation.detect_violation("hello", "user1", state, @default_config, now)
    end
  end

  describe "handles empty/uninitialized state" do
    test "handle_message with empty map state does not crash" do
      ctx = %{@ctx | capability_state: %{}}
      result = Moderation.handle_message("hello world", "user1", ctx)
      assert {:side_effect, %{state_update: state}} = result
      assert Map.has_key?(state, :message_history)
      assert Map.has_key?(state, :warnings)
    end

    test "handle_message with empty state detects blocked words" do
      config = Map.put(@default_config, "blocked_words", ["badword"])
      ctx = %{@ctx | config: config, capability_state: %{}}
      result = Moderation.handle_message("badword here", "user1", ctx)
      assert {:reply, msg, state} = result
      assert msg =~ "blocked words"
      assert Map.has_key?(state, :warnings)
    end

    test "handle_message with empty state tracks messages correctly" do
      ctx = %{@ctx | capability_state: %{}}
      {:side_effect, %{state_update: state1}} = Moderation.handle_message("msg1", "user1", ctx)

      ctx2 = %{@ctx | capability_state: state1}
      {:side_effect, %{state_update: state2}} = Moderation.handle_message("msg2", "user1", ctx2)

      assert length(state2.message_history["user1"]) == 2
    end
  end
end
