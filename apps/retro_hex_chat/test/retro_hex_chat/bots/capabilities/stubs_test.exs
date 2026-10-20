defmodule RetroHexChat.Bots.Capabilities.StubsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  # Only LLM, Script, and Game remain as stubs
  @stub_modules [
    RetroHexChat.Bots.Capabilities.LLM,
    RetroHexChat.Bots.Capabilities.Script,
    RetroHexChat.Bots.Capabilities.Game
  ]

  @ctx %{
    bot_nickname: "StubBot",
    bot_name: "StubBot",
    channel: "#test",
    command_prefix: "!",
    config: %{},
    capability_state: %{}
  }

  for mod <- @stub_modules do
    short_name = mod |> Module.split() |> List.last()

    describe "#{short_name}" do
      test "handle_message/3 returns :ignore" do
        assert :ignore == unquote(mod).handle_message("test", "user", @ctx)
      end

      test "handle_event/3 returns :ignore" do
        assert :ignore == unquote(mod).handle_event(:user_joined, %{}, @ctx)
      end

      test "validate_config/1 returns :ok" do
        assert :ok == unquote(mod).validate_config(%{})
      end

      test "commands/0 returns empty list" do
        assert [] == unquote(mod).commands()
      end
    end
  end
end
