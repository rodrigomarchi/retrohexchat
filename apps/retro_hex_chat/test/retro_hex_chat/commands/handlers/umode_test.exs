defmodule RetroHexChat.Commands.Handlers.UmodeTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Umode

  @base_context %{
    nickname: "TestUser",
    active_channel: nil,
    channels: [],
    identified: false,
    operator_in: [],
    half_operator_in: [],
    is_admin: false,
    is_server_operator: false
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Umode.validate("+w")
      assert :ok = Umode.validate("")
    end
  end

  describe "execute/2" do
    test "no args returns usage error" do
      assert {:error, "Usage: /umode <+/-mode>"} =
               Umode.execute([], @base_context)
    end

    test "+w returns set_user_mode ui_action" do
      assert {:ok, :ui_action, :set_user_mode, %{mode_string: "+w"}} =
               Umode.execute(["+w"], @base_context)
    end

    test "-w returns set_user_mode ui_action" do
      assert {:ok, :ui_action, :set_user_mode, %{mode_string: "-w"}} =
               Umode.execute(["-w"], @base_context)
    end

    test "unknown mode returns error" do
      assert {:error, "Unknown user mode: x"} =
               Umode.execute(["+x"], @base_context)
    end

    test "invalid format returns usage error" do
      assert {:error, "Usage: /umode <+/-mode>"} =
               Umode.execute(["w"], @base_context)
    end

    test "empty mode flag returns usage error" do
      assert {:error, "Usage: /umode <+/-mode>"} =
               Umode.execute(["+"], @base_context)
    end

    test "extra args are ignored" do
      assert {:ok, :ui_action, :set_user_mode, %{mode_string: "+w"}} =
               Umode.execute(["+w", "extra", "args"], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Umode.help()
      assert help.name == "umode"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
