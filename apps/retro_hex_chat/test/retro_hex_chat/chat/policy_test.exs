defmodule RetroHexChat.Chat.PolicyTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.Policy

  describe "validate_content/1" do
    test "accepts content within limit" do
      assert :ok = Policy.validate_content("Hello!")
    end

    test "rejects empty content" do
      assert {:error, "Message cannot be empty"} = Policy.validate_content("")
    end

    test "rejects content exceeding 1000 characters" do
      content = String.duplicate("a", 1001)
      assert {:error, _} = Policy.validate_content(content)
    end

    test "accepts content at exactly 1000 characters" do
      content = String.duplicate("a", 1000)
      assert :ok = Policy.validate_content(content)
    end

    test "rejects message with only format codes (no visible text)" do
      # Bold toggle only — no visible text
      assert {:error, "Message cannot be empty"} = Policy.validate_content(<<0x02, 0x02>>)
    end

    test "rejects message with format codes and whitespace only" do
      assert {:error, "Message cannot be empty"} =
               Policy.validate_content(<<0x02>> <> "   " <> <<0x02>>)
    end

    test "accepts message with format codes and visible text" do
      assert :ok = Policy.validate_content(<<0x02>> <> "Hello" <> <<0x02>>)
    end

    test "rejects message with only color codes" do
      assert {:error, "Message cannot be empty"} =
               Policy.validate_content(<<0x03>> <> "4" <> <<0x03>>)
    end

    test "accepts message with color codes and visible text" do
      assert :ok = Policy.validate_content(<<0x03>> <> "4Red text" <> <<0x03>>)
    end

    test "rejects message with reset code only" do
      assert {:error, "Message cannot be empty"} = Policy.validate_content(<<0x0F>>)
    end
  end

  describe "check_rate_limit/2" do
    setup do
      table = :ets.new(:chat_policy_rate_test, [:set, :public])
      {:ok, table: table}
    end

    test "returns :ok for first message", %{table: table} do
      assert :ok = Policy.check_rate_limit(table, "rate_user_1")
    end

    test "returns :ok for multiple messages within limit", %{table: table} do
      assert :ok = Policy.check_rate_limit(table, "rate_user_2")
      assert :ok = Policy.check_rate_limit(table, "rate_user_2")
      assert :ok = Policy.check_rate_limit(table, "rate_user_2")
    end

    test "returns {:error, :rate_limited} after exhausting tokens", %{table: table} do
      user = "rate_user_3"
      # Consume all 5 message tokens (1 on init + 4 remaining)
      for _ <- 1..5, do: Policy.check_rate_limit(table, user)
      assert {:error, :rate_limited} = Policy.check_rate_limit(table, user)
    end
  end
end
