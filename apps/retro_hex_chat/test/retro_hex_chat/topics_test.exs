defmodule RetroHexChat.TopicsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Topics

  # These strings are a wire format: a publisher and a subscriber in different
  # applications have to agree on them, and nothing else checks that they do.
  test "an inbox is named by the person's nickname key" do
    assert Topics.inbox("Alice") == "user:alice"
  end

  test "a channel keeps the leading hash the name carries" do
    assert Topics.channel("#lobby") == "channel:#lobby"
  end

  test "every case of a nickname is one inbox, because it is one person" do
    assert Topics.inbox("aLiCe") == Topics.inbox("ALICE")
  end

  # A surface that is not the chat subscribes here and nowhere else. If this
  # ever became a prefix of the inbox, a satellite would start receiving private
  # messages it has no handler for.
  test "surfaces is a topic of its own, not a prefix of the inbox" do
    assert Topics.surfaces("Alice") == "user:alice:surfaces"
    refute Topics.surfaces("Alice") == Topics.inbox("Alice")
  end

  # The suffix is only unambiguous because a nickname cannot contain the
  # separator: `Topics.inbox("Alice:surfaces")` and `Topics.surfaces("Alice")`
  # are the same string, and what keeps that unreachable is the validator, not
  # the topic builder. Widen the nickname charset and this goes red first.
  test "the separator is what a nickname may never contain" do
    assert Topics.inbox("Alice:surfaces") == Topics.surfaces("Alice")
    refute NicknameValidator.valid?("Alice:surfaces")
  end
end
