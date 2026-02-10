defmodule RetroHexChat.RateLimit.TableTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias RetroHexChat.RateLimit.Table

  describe "table_name/0" do
    test "returns :retro_hex_chat_rate_limit" do
      assert Table.table_name() == :retro_hex_chat_rate_limit
    end
  end

  describe "ETS table" do
    test "table exists and is accessible" do
      table = Table.table_name()
      info = :ets.info(table)
      assert info != :undefined
      assert Keyword.get(info, :type) == :set
      assert Keyword.get(info, :named_table) == true
      assert Keyword.get(info, :protection) == :public
    end

    test "accepts read/write operations" do
      table = Table.table_name()
      key = "table_test_user_#{System.unique_integer([:positive])}"
      :ets.insert(table, {key, "value"})
      assert [{^key, "value"}] = :ets.lookup(table, key)
      :ets.delete(table, key)
    end
  end
end
