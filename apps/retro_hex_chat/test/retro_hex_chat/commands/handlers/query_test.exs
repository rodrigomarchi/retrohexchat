defmodule RetroHexChat.Commands.Handlers.QueryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Query

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts non-empty args" do
      assert :ok = Query.validate("Nick")
    end

    test "rejects empty args" do
      assert {:error, _} = Query.validate("")
    end
  end

  describe "execute/2" do
    test "opens a PM window for target nickname" do
      assert {:ok, :ui_action, :open_query, %{nickname: "Nick"}} =
               Query.execute(["Nick"], @base_context)
    end

    test "returns error when no target" do
      assert {:error, _} = Query.execute([], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Query.help()
      assert help.name == "query"
      assert is_binary(help.syntax)
    end
  end
end
