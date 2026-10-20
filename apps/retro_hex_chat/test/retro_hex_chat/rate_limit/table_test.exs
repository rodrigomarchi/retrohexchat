defmodule RetroHexChat.RateLimit.TableTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias RetroHexChat.RateLimit.Table

  describe "ETS table" do
    test "table exists and is accessible" do
      table = Table.table_name()
      info = :ets.info(table)
      assert info != :undefined
      assert Keyword.get(info, :type) == :set
      assert Keyword.get(info, :named_table) == true
      assert Keyword.get(info, :protection) == :public
    end
  end
end
