defmodule RetroHexChat.Chat.QueriesNewestLineTest do
  @moduledoc """
  The one question the door controls ask before writing a card again.

  Pressing "Space" or "Group Call" on a conversation that already has the room
  open writes the card a second time, on purpose: somebody presses twice because
  they cannot find the first one, and a sentence saying it exists further up is
  not an answer. The single press that must write nothing is the one where the
  card is already the line at the bottom — which is what a double click is.
  """
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Chat.Queries

  defp say(channel, content) do
    {:ok, message} =
      Queries.insert_message(%{
        channel_name: channel,
        author_nickname: "System",
        content: content,
        type: "system"
      })

    message
  end

  defp whisper(from, to, content) do
    {:ok, pm} =
      Queries.insert_private_message(%{
        sender_nickname: from,
        recipient_nickname: to,
        content: content,
        type: "system"
      })

    pm
  end

  describe "a channel" do
    test "says so when the card is the line at the bottom" do
      channel = "#nl#{System.unique_integer([:positive])}"
      say(channel, "Ada opened the space — https://host/join/abc123")

      assert Queries.newest_line_carries?({:channel, channel}, "abc123")
    end

    # The point of the whole thing: one line of conversation and the card is no
    # longer where the reader is looking, so pressing must bring it back down.
    test "says no once anything at all has been said after it" do
      channel = "#nl#{System.unique_integer([:positive])}"
      say(channel, "Ada opened the space — https://host/join/abc123")
      say(channel, "Grace walked in.")

      refute Queries.newest_line_carries?({:channel, channel}, "abc123")
    end

    test "an empty conversation carries nothing" do
      refute Queries.newest_line_carries?(
               {:channel, "#nl#{System.unique_integer([:positive])}"},
               "abc123"
             )
    end

    # A deleted card is not a card anybody can read, so it does not count as one
    # being there — pressing has to write a new one.
    test "a deleted last line does not count as the card being there" do
      channel = "#nl#{System.unique_integer([:positive])}"
      message = say(channel, "Ada opened the space — https://host/join/abc123")
      {:ok, _deleted} = Queries.soft_delete(message, DateTime.utc_now())

      refute Queries.newest_line_carries?({:channel, channel}, "abc123")
    end

    # Absence: a different room's address is a different card. Without the
    # containment check this would pass for any link at all.
    test "another room's card is not this one" do
      channel = "#nl#{System.unique_integer([:positive])}"
      say(channel, "Ada opened the space — https://host/join/abc123")

      refute Queries.newest_line_carries?({:channel, channel}, "zzz999")
    end

    test "a fragment that is not a fragment is never carried" do
      channel = "#nl#{System.unique_integer([:positive])}"
      say(channel, "Ada opened the space — https://host/join/abc123")

      refute Queries.newest_line_carries?({:channel, channel}, "")
      refute Queries.newest_line_carries?({:channel, channel}, nil)
    end
  end

  describe "a private conversation" do
    test "reads the pair's own newest line, from either side" do
      a = "Ada#{System.unique_integer([:positive])}"
      b = "Grace#{System.unique_integer([:positive])}"
      whisper(a, b, "Ada opened the space — https://host/join/pm4242")

      assert Queries.newest_line_carries?({:pm, a, b}, "pm4242")
      assert Queries.newest_line_carries?({:pm, b, a}, "pm4242")
    end

    test "a reply after the card puts it out of reach again" do
      a = "Ada#{System.unique_integer([:positive])}"
      b = "Grace#{System.unique_integer([:positive])}"
      whisper(a, b, "Ada opened the space — https://host/join/pm4242")
      whisper(b, a, "be right there")

      refute Queries.newest_line_carries?({:pm, a, b}, "pm4242")
    end

    # Absence: somebody else's conversation is not this one. Drop the pair
    # filter and this goes green on the wrong card.
    test "another pair's card is not in this conversation" do
      a = "Ada#{System.unique_integer([:positive])}"
      b = "Grace#{System.unique_integer([:positive])}"
      c = "Alan#{System.unique_integer([:positive])}"
      whisper(a, b, "Ada opened the space — https://host/join/pm4242")

      refute Queries.newest_line_carries?({:pm, a, c}, "pm4242")
    end
  end
end
