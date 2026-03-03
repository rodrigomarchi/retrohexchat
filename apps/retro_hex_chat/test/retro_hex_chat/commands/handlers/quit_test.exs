defmodule RetroHexChat.Commands.Handlers.QuitTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Quit

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty args" do
      assert :ok = Quit.validate("")
    end

    test "accepts non-empty args" do
      assert :ok = Quit.validate("Goodbye!")
    end
  end

  describe "execute/2" do
    test "returns quit with reason" do
      assert {:ok, :quit, "Goodbye everyone"} =
               Quit.execute(["Goodbye", "everyone"], @base_context)
    end

    test "returns quit with nil when no args" do
      assert {:ok, :quit, nil} = Quit.execute([], @base_context)
    end

    test "returns quit with single word reason" do
      assert {:ok, :quit, "Bye"} = Quit.execute(["Bye"], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Quit.help()
      assert help.name == "quit"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
