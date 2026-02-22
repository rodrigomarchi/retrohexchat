defmodule RetroHexChat.Bots.CapabilityTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capability

  describe "behaviour" do
    test "defines required callbacks" do
      callbacks = Capability.behaviour_info(:callbacks)
      assert {:name, 0} in callbacks
      assert {:description, 0} in callbacks
      assert {:handle_message, 3} in callbacks
      assert {:handle_event, 3} in callbacks
      assert {:default_config, 0} in callbacks
      assert {:validate_config, 1} in callbacks
    end

    test "defines optional callbacks" do
      optional = Capability.behaviour_info(:optional_callbacks)
      assert {:commands, 0} in optional
      assert {:init_state, 1} in optional
      assert {:handle_timer, 3} in optional
      assert {:passive?, 0} in optional
    end
  end
end
