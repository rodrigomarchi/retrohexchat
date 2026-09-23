defmodule RetroHexChat.Commands.Handlers.PinTest do
  @moduledoc """
  `/pin` and `/unpin`, and what they refuse before reaching the channel.

  The handler decides nothing about permission — that is the channel's, checked
  where the pin is actually written. What it owns is the shape of the request:
  an id that is an id, and a channel to pin it in.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Pin
  alias RetroHexChat.Commands.Handlers.Unpin

  @context %{active_channel: "#lobby"}

  describe "/pin" do
    test "asks which message when given none" do
      assert {:error, message} = Pin.execute([], @context)
      assert message =~ "/pin"
    end

    test "hands the id to the channel" do
      assert {:ok, :ui_action, :pin_message, %{channel: "#lobby", message_id: 1284}} =
               Pin.execute(["1284"], @context)
    end

    test "refuses something that is not an id" do
      assert {:error, _reason} = Pin.execute(["not-a-number"], @context)
      assert {:error, _reason} = Pin.execute(["12abc"], @context)
      assert {:error, _reason} = Pin.execute(["0"], @context)
      assert {:error, _reason} = Pin.execute(["-3"], @context)
    end

    test "refuses when there is no channel to pin in" do
      assert {:error, _reason} = Pin.execute(["1284"], %{active_channel: nil})
    end

    test "describes itself for the help window" do
      assert %{name: "pin", syntax: syntax} = Pin.help()
      assert syntax =~ "/pin"
      assert Pin.category() == :channel
      assert Pin.syntax_definition().command == "pin"
    end
  end

  describe "/unpin" do
    test "asks which message when given none" do
      assert {:error, message} = Unpin.execute([], @context)
      assert message =~ "/unpin"
    end

    test "hands the id to the channel" do
      assert {:ok, :ui_action, :unpin_message, %{channel: "#lobby", message_id: 7}} =
               Unpin.execute(["7"], @context)
    end

    test "refuses something that is not an id" do
      assert {:error, _reason} = Unpin.execute(["nope"], @context)
    end

    test "describes itself for the help window" do
      assert %{name: "unpin"} = Unpin.help()
      assert Unpin.syntax_definition().command == "unpin"
    end
  end
end
