defmodule RetroHexChat.TopicsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Topics

  # These strings are a wire format: a publisher and a subscriber in different
  # applications have to agree on them, and nothing else checks that they do.
  test "an inbox is the person's nickname" do
    assert Topics.inbox("Alice") == "user:Alice"
  end

  test "a channel keeps the leading hash the name carries" do
    assert Topics.channel("#lobby") == "channel:#lobby"
  end

  test "case is preserved, because a nickname is addressed as it was written" do
    assert Topics.inbox("aLiCe") == "user:aLiCe"
  end
end
