defmodule RetroHexChat.Commands.Handlers.JoinTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Join

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts non-empty args" do
      assert :ok = Join.validate("#elixir")
    end

    test "rejects empty args" do
      assert {:error, _} = Join.validate("")
    end
  end

  describe "execute/2" do
    test "returns join for valid channel" do
      assert {:ok, :join, "#elixir", nil} = Join.execute(["#elixir"], @base_context)
    end

    test "rejects channel without # prefix" do
      assert {:error, _} = Join.execute(["elixir"], @base_context)
    end

    test "rejects channel name too long" do
      long_name = "#" <> String.duplicate("a", 50)
      assert {:error, _} = Join.execute([long_name], @base_context)
    end

    test "rejects when already in channel" do
      assert {:error, _} = Join.execute(["#lobby"], @base_context)
    end

    test "rejects when at 10 channel limit" do
      ctx = %{@base_context | channels: Enum.map(1..10, &"#chan#{&1}")}
      assert {:error, "Maximum channel limit reached (10)"} = Join.execute(["#new"], ctx)
    end

    test "returns join with password in result tuple" do
      assert {:ok, :join, "#secret", "mypass"} =
               Join.execute(["#secret", "mypass"], @base_context)
    end

    test "returns join with nil password when not provided" do
      assert {:ok, :join, "#elixir", nil} = Join.execute(["#elixir"], @base_context)
    end

    test "rejects empty args" do
      assert {:error, _} = Join.execute([], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Join.help()
      assert help.name == "join"
      assert is_binary(help.syntax)
    end
  end
end
