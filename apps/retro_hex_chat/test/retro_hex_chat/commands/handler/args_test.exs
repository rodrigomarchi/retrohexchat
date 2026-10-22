defmodule RetroHexChat.Commands.Handler.ArgsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handler.Args

  test "nickname/1 drops the operator's @" do
    assert Args.nickname("@alice") == "alice"
    assert Args.nickname("alice") == "alice"
  end

  test "option/2 reads the word after a flag" do
    assert Args.option(["user", "--reason", "spam"], "--reason") == "spam"
    assert Args.option(["user", "--reason"], "--reason") == nil
    assert Args.option(["user"], "--reason") == nil
  end

  test "positive_id/2 accepts a positive whole number only" do
    assert Args.positive_id(" 42 ", :bad) == {:ok, 42}
    assert Args.positive_id("0", :bad) == {:error, :bad}
    assert Args.positive_id("4x", :bad) == {:error, :bad}
    assert Args.positive_id(nil, :bad) == {:error, :bad}
  end
end
