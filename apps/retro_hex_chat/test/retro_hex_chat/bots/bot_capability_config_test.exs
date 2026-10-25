defmodule RetroHexChat.Bots.BotCapabilityConfigTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Bot

  test "a capability set up and switched on hands back its configuration" do
    bot = %Bot{capabilities: %{"rss" => %{"feeds" => []}}}
    assert {:ok, %{"feeds" => []}} = Bot.capability_config(bot, "rss")
  end

  test "switched off is disabled, never set up is missing" do
    assert {:error, :disabled} =
             Bot.capability_config(%Bot{capabilities: %{"rss" => %{"enabled" => false}}}, "rss")

    assert {:error, :missing} = Bot.capability_config(%Bot{capabilities: %{}}, "rss")
    assert {:error, :missing} = Bot.capability_config(%Bot{capabilities: nil}, "scheduler")
  end
end
