defmodule RetroHexChat.Chat.LinkPreview.CacheTest do
  use ExUnit.Case, async: false

  alias RetroHexChat.Chat.LinkPreview.Cache

  @moduletag :unit

  setup do
    # Start a fresh cache for each test with a unique name
    name = :"cache_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = Cache.start_link(name: name, table_name: name)
    %{cache: pid, table: name}
  end

  describe "get/1" do
    test "returns :miss for uncached URL", %{table: table} do
      assert Cache.get("https://example.com", table) == :miss
    end

    test "returns :miss for empty table", %{table: table} do
      assert Cache.get("https://never-cached.com", table) == :miss
    end
  end

  describe "put/2 and get/1" do
    test "stores and retrieves a title", %{table: table} do
      Cache.put("https://example.com", "Example Domain", table)
      assert Cache.get("https://example.com", table) == {:ok, "Example Domain"}
    end

    test "stores nil title", %{table: table} do
      Cache.put("https://example.com", nil, table)
      assert Cache.get("https://example.com", table) == {:ok, nil}
    end
  end

  describe "pending?/1 and mark_pending/1" do
    test "returns false for URL not marked pending", %{table: table} do
      refute Cache.pending?("https://example.com", table)
    end

    test "returns true after marking pending", %{table: table} do
      Cache.mark_pending("https://example.com", table)
      assert Cache.pending?("https://example.com", table)
    end

    test "put/2 clears pending flag", %{table: table} do
      Cache.mark_pending("https://example.com", table)
      assert Cache.pending?("https://example.com", table)

      Cache.put("https://example.com", "Example Domain", table)
      refute Cache.pending?("https://example.com", table)
    end
  end

  describe "put_error/1" do
    test "stores error marker and get returns {:ok, :error}", %{table: table} do
      Cache.put_error("https://bad.com", table)
      assert Cache.get("https://bad.com", table) == {:ok, :error}
    end

    test "clears pending flag", %{table: table} do
      Cache.mark_pending("https://bad.com", table)
      Cache.put_error("https://bad.com", table)
      refute Cache.pending?("https://bad.com", table)
    end
  end
end
