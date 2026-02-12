defmodule RetroHexChat.Commands.Handlers.WhowasTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Whowas

  @base_context %{
    nickname: "Rodrigo",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts non-empty args" do
      assert :ok = Whowas.validate("SomeUser")
    end

    test "rejects empty args" do
      assert {:error, _} = Whowas.validate("")
    end
  end

  describe "execute/2" do
    test "returns show_whowas_info for valid target" do
      assert {:ok, :ui_action, :show_whowas_info, %{nickname: "Bob"}} =
               Whowas.execute(["Bob"], @base_context)
    end

    test "uses first arg as target when multiple provided" do
      assert {:ok, :ui_action, :show_whowas_info, %{nickname: "Bob"}} =
               Whowas.execute(["Bob", "extra"], @base_context)
    end

    test "errors when no target provided" do
      assert {:error, _} = Whowas.execute([], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Whowas.help()
      assert help.name == "whowas"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
