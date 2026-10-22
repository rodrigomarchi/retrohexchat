defmodule RetroHexChat.RateLimit.WindowTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.RateLimit.Window

  setup do
    %{table: :ets.new(:window_test, [:set, :public])}
  end

  test "allows max_count hits, then says how long the window still blocks", %{table: table} do
    assert :ok = Window.check(table, :k, {2, 60_000})
    assert :ok = Window.check(table, :k, {2, 60_000})
    assert {:error, {:rate_limited, ms}} = Window.check(table, :k, {2, 60_000})
    assert ms > 59_000 and ms <= 60_000
  end

  test "keys count apart", %{table: table} do
    assert :ok = Window.check(table, :a, {1, 60_000})
    assert :ok = Window.check(table, :b, {1, 60_000})
  end

  test "a window that has passed starts again", %{table: table} do
    assert :ok = Window.check(table, :k, {1, 1})
    Process.sleep(2)
    assert :ok = Window.check(table, :k, {1, 1})
  end

  test "reset forgets the key", %{table: table} do
    assert :ok = Window.check(table, :k, {1, 60_000})
    assert :ok = Window.reset(table, :k)
    assert :ok = Window.check(table, :k, {1, 60_000})
  end

  test "seconds/1 rounds up and never answers zero" do
    assert Window.seconds(1) == 1
    assert Window.seconds(1_000) == 1
    assert Window.seconds(1_001) == 2
  end
end
