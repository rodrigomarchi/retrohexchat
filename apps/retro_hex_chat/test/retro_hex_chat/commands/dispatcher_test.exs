defmodule RetroHexChat.Commands.DispatcherTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Dispatcher

  defp default_context do
    %{
      nickname: "Alice",
      active_channel: "#lobby",
      channels: ["#lobby"],
      identified: false,
      operator_in: []
    }
  end

  describe "dispatch/3" do
    test "returns error for unknown command" do
      assert {:error, "Unknown command: /unknown. Type /help for a list of commands."} =
               Dispatcher.dispatch("unknown", [], default_context())
    end

    test "dispatching a valid command with valid args returns handler result" do
      # /help always validates :ok and returns a known result
      assert {:ok, :ui_action, :show_help, %{commands: commands}} =
               Dispatcher.dispatch("help", [], default_context())

      assert is_list(commands)
    end

    test "dispatching a command that fails validation returns the validation error" do
      # /join with no channel name — validate should return an error
      assert {:error, msg} = Dispatcher.dispatch("join", [], default_context())
      assert is_binary(msg)
    end
  end
end
