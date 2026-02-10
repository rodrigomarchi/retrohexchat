defmodule RetroHexChat.Chat.ServiceTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.Service

  describe "send_message/4" do
    test "persists and returns message for valid input" do
      assert {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "Hello!")
      assert msg.channel_name == "#lobby"
      assert msg.author_nickname == "Rodrigo"
      assert msg.content == "Hello!"
      assert msg.type == "message"
    end

    test "supports custom type" do
      assert {:ok, msg} = Service.send_message("#lobby", "Rodrigo", "does something", "action")
      assert msg.type == "action"
    end

    test "rejects empty content" do
      assert {:error, "Message cannot be empty"} = Service.send_message("#lobby", "Rodrigo", "")
    end

    test "rejects content exceeding 1000 characters" do
      long_content = String.duplicate("a", 1001)
      assert {:error, _} = Service.send_message("#lobby", "Rodrigo", long_content)
    end
  end

  describe "send_private_message/4" do
    test "persists and returns PM for valid input" do
      assert {:ok, pm} = Service.send_private_message("Alice", "Bob", "Hello PM!")
      assert pm.sender_nickname == "Alice"
      assert pm.recipient_nickname == "Bob"
      assert pm.content == "Hello PM!"
    end

    test "rejects empty content" do
      assert {:error, "Message cannot be empty"} =
               Service.send_private_message("Alice", "Bob", "")
    end

    test "rejects content exceeding 1000 characters" do
      long_content = String.duplicate("a", 1001)
      assert {:error, _} = Service.send_private_message("Alice", "Bob", long_content)
    end
  end

  describe "send_system_message/2" do
    test "persists system message" do
      assert {:ok, msg} = Service.send_system_message("#lobby", "User joined")
      assert msg.type == "system"
      assert msg.author_nickname == "System"
    end
  end
end
