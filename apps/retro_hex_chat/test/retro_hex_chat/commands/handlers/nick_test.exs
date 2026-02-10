defmodule RetroHexChat.Commands.Handlers.NickTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Nick

  @base_context %{
    nickname: "Rodrigo",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts non-empty args" do
      assert :ok = Nick.validate("NewNick")
    end

    test "rejects empty args" do
      assert {:error, _} = Nick.validate("")
    end
  end

  describe "execute/2" do
    test "returns nick_change for valid nickname" do
      assert {:ok, :nick_change, "NewNick"} = Nick.execute(["NewNick"], @base_context)
    end

    test "accepts nickname starting with letter" do
      assert {:ok, :nick_change, "Alice"} = Nick.execute(["Alice"], @base_context)
    end

    test "accepts nickname starting with special char [" do
      assert {:ok, :nick_change, "[bot]"} = Nick.execute(["[bot]"], @base_context)
    end

    test "accepts nickname starting with backslash" do
      assert {:ok, :nick_change, "\\admin"} = Nick.execute(["\\admin"], @base_context)
    end

    test "accepts nickname starting with ]" do
      assert {:ok, :nick_change, "]test"} = Nick.execute(["]test"], @base_context)
    end

    test "accepts nickname starting with ^" do
      assert {:ok, :nick_change, "^cool"} = Nick.execute(["^cool"], @base_context)
    end

    test "accepts nickname starting with _" do
      assert {:ok, :nick_change, "_under"} = Nick.execute(["_under"], @base_context)
    end

    test "accepts nickname starting with {" do
      assert {:ok, :nick_change, "{curly"} = Nick.execute(["{curly"], @base_context)
    end

    test "accepts nickname starting with |" do
      assert {:ok, :nick_change, "|pipe"} = Nick.execute(["|pipe"], @base_context)
    end

    test "accepts nickname starting with }" do
      assert {:ok, :nick_change, "}brace"} = Nick.execute(["}brace"], @base_context)
    end

    test "accepts nickname with alphanumeric and allowed specials" do
      assert {:ok, :nick_change, "Nick_123"} = Nick.execute(["Nick_123"], @base_context)
    end

    test "errors when same as current nick" do
      assert {:error, _} = Nick.execute(["Rodrigo"], @base_context)
    end

    test "errors when nickname too long (over 16 chars)" do
      long_nick = String.duplicate("a", 17)
      assert {:error, _} = Nick.execute([long_nick], @base_context)
    end

    test "errors when nickname starts with a digit" do
      assert {:error, _} = Nick.execute(["1invalid"], @base_context)
    end

    test "errors when nickname contains spaces" do
      assert {:error, _} = Nick.execute(["bad", "nick"], @base_context)
    end

    test "errors when no args provided" do
      assert {:error, _} = Nick.execute([], @base_context)
    end

    test "errors when nickname contains invalid characters" do
      assert {:error, _} = Nick.execute(["bad@nick"], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Nick.help()
      assert help.name == "nick"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
