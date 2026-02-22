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
      test "implements name/0" do
        assert is_atom(unquote(mod).name())
      end

      test "implements description/0" do
        desc = unquote(mod).description()
        assert is_binary(desc)
        assert desc =~ "Coming soon"
      end

      test "handle_message/3 returns :ignore" do
        assert :ignore == unquote(mod).handle_message("test", "user", @ctx)
      end

      test "handle_event/3 returns :ignore" do
        assert :ignore == unquote(mod).handle_event(:user_joined, %{}, @ctx)
      end

      test "default_config/0 returns a map" do
        assert is_map(unquote(mod).default_config())
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
