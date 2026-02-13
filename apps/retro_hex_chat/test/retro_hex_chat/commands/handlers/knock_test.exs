defmodule RetroHexChat.Commands.Handlers.KnockTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Knock

  @base_context %{
    nickname: "Rodrigo",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: [],
    half_operator_in: []
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Knock.validate("#channel message")
      assert :ok = Knock.validate("")
    end
  end

  describe "execute/2" do
    test "/knock #channel returns knock_channel ui_action" do
      assert {:ok, :ui_action, :knock_channel, %{channel: "#private", message: nil}} =
               Knock.execute(["#private"], @base_context)
    end

    test "/knock #channel with message joins message words" do
      assert {:ok, :ui_action, :knock_channel,
              %{channel: "#private", message: "Let me in please"}} =
               Knock.execute(["#private", "Let", "me", "in", "please"], @base_context)
    end

    test "/knock with no args returns error" do
      assert {:error, "Usage: /knock" <> _} = Knock.execute([], @base_context)
    end

    test "/knock with invalid channel name returns error" do
      assert {:error, _} = Knock.execute(["nochannel"], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Knock.help()
      assert help.name == "knock"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
