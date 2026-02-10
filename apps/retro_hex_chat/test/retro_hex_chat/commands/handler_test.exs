defmodule RetroHexChat.Commands.HandlerTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handler

  describe "behaviour" do
    test "defines execute/2 callback" do
      callbacks = Handler.behaviour_info(:callbacks)
      assert {:execute, 2} in callbacks
    end

    test "defines validate/1 and help/0 callbacks" do
      callbacks = Handler.behaviour_info(:callbacks)
      assert {:validate, 1} in callbacks
      assert {:help, 0} in callbacks
    end
  end
end
