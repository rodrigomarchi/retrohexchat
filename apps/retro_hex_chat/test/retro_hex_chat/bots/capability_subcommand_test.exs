defmodule RetroHexChat.Bots.CapabilitySubcommandTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capability

  test "reads what follows the command, in any case" do
    assert Capability.subcommand("!Bot RSS add x #c", "!", "bot", "rss") == {:ok, "add x #c"}
    assert Capability.subcommand("!bot rss", "!", "Bot", "rss") == {:ok, ""}
  end

  test "takes aliases, and the word must end where the command ends" do
    assert Capability.subcommand("!bot dice 2d6", "!", "bot", ["roll", "dice"]) == {:ok, "2d6"}
    assert Capability.subcommand("!bot triviaplease", "!", "bot", "trivia") == :error
    assert Capability.subcommand("!other rss list", "!", "bot", "rss") == :error
  end
end
