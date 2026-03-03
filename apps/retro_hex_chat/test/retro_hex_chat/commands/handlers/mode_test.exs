defmodule RetroHexChat.Commands.Handlers.ModeTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Mode

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: ["#lobby"]
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Mode.validate("+m")
      assert :ok = Mode.validate("")
      assert :ok = Mode.validate("+k secret")
    end
  end

  describe "execute/2" do
    test "/mode +m returns set_mode ui_action" do
      assert {:ok, :ui_action, :set_mode, %{channel: "#lobby", mode_string: "+m", params: []}} =
               Mode.execute(["+m"], @base_context)
    end

    test "/mode +k secret includes params" do
      assert {:ok, :ui_action, :set_mode,
              %{channel: "#lobby", mode_string: "+k", params: ["secret"]}} =
               Mode.execute(["+k", "secret"], @base_context)
    end

    test "/mode +l 10 includes limit param" do
      assert {:ok, :ui_action, :set_mode, %{channel: "#lobby", mode_string: "+l", params: ["10"]}} =
               Mode.execute(["+l", "10"], @base_context)
    end

    test "/mode with no args returns error" do
      assert {:error, "Usage: /mode <+/-flags> [params]"} =
               Mode.execute([], @base_context)
    end

    test "non-operator receives error" do
      ctx = %{@base_context | operator_in: []}

      assert {:error, "You must be a channel operator to change modes"} =
               Mode.execute(["+m"], ctx)
    end

    test "no active channel returns error" do
      ctx = %{@base_context | active_channel: nil}

      assert {:error, "You are not in any channel"} =
               Mode.execute(["+m"], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Mode.help()
      assert help.name == "mode"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
