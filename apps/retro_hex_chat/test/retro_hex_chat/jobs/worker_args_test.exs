defmodule RetroHexChat.Jobs.WorkerArgsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Jobs.WorkerArgs

  describe "positive_integer/3" do
    test "reads a positive integer" do
      assert 25 = WorkerArgs.positive_integer(%{"limit" => 25}, "limit", 100)
    end

    test "falls back when the key is missing" do
      assert 100 = WorkerArgs.positive_integer(%{}, "limit", 100)
    end

    test "falls back on zero, negatives and non-integers" do
      for value <- [0, -5, "25", 2.5, nil] do
        assert 100 = WorkerArgs.positive_integer(%{"limit" => value}, "limit", 100)
      end
    end
  end

  describe "positive_id/1" do
    test "accepts a positive integer" do
      assert {:ok, 42} = WorkerArgs.positive_id(42)
    end

    test "accepts the decimal string of a positive integer" do
      assert {:ok, 42} = WorkerArgs.positive_id("42")
    end

    test "refuses a string carrying trailing characters" do
      assert :error = WorkerArgs.positive_id("42abc")
      assert :error = WorkerArgs.positive_id("42 ")
    end

    test "refuses zero, negatives and anything else" do
      for value <- [0, -1, "0", "-1", "", nil, 4.2, %{}] do
        assert :error = WorkerArgs.positive_id(value)
      end
    end
  end
end
