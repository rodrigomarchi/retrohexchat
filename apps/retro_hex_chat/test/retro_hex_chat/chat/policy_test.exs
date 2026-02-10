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
