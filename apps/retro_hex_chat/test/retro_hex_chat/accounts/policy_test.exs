defmodule RetroHexChat.Accounts.PolicyTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Accounts.Policy
  alias RetroHexChat.Accounts.Session

  describe "identified?/1" do
    test "returns true when session is identified" do
      session = Session.new("Alice") |> Session.set_identified(true)
      assert Policy.identified?(session)
    end

    test "returns false when session is not identified" do
      session = Session.new("Alice")
      refute Policy.identified?(session)
    end
  end

  describe "in_channel?/2" do
    test "returns true when session is in the given channel" do
      session = Session.new("Alice") |> Session.add_channel("#general")
      assert Policy.in_channel?(session, "#general")
    end

    test "returns false when session is not in the given channel" do
      session = Session.new("Alice") |> Session.add_channel("#general")
      refute Policy.in_channel?(session, "#random")
    end

    test "returns false when session has no channels" do
      session = Session.new("Alice")
      refute Policy.in_channel?(session, "#general")
    end
  end
end
