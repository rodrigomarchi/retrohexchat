defmodule RetroHexChat.Chat.ConversationTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.Conversation
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Chat.PrivateMessage

  describe "topics/1" do
    test "a channel message goes to the channel everybody joined" do
      assert Conversation.topics(%Message{channel_name: "#lobby"}) == ["channel:#lobby"]
    end

    # Both, and not a topic named after the pair: a private conversation has no
    # join, so the one place it is certain to be read is each person's inbox.
    test "a private message goes to both people" do
      pm = %PrivateMessage{sender_nickname: "Ada", recipient_nickname: "Grace"}

      assert Conversation.topics(pm) == ["user:Ada", "user:Grace"]
    end

    test "the writer hears about their own message too" do
      pm = %PrivateMessage{sender_nickname: "Ada", recipient_nickname: "Grace"}

      assert "user:Ada" in Conversation.topics(pm)
    end
  end

  describe "address/1" do
    # `message_edited` and `message_deleted` carry the same event name for both
    # kinds of conversation, so the reader tells them apart by which of these
    # two keys the payload has. Changing either breaks a handler that has no
    # other way to ask.
    test "a channel message names its channel" do
      assert Conversation.address(%Message{channel_name: "#lobby"}) == %{channel: "#lobby"}
    end

    test "a private message names its sender" do
      pm = %PrivateMessage{sender_nickname: "Ada", recipient_nickname: "Grace"}

      assert Conversation.address(pm) == %{sender: "Ada"}
    end
  end
end
