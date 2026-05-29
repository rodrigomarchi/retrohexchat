defmodule RetroHexChat.Chat.PrivateMessageTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.PrivateMessage

  @moduletag :unit

  describe "changeset/2" do
    test "valid attrs produce a valid changeset" do
      attrs = %{sender_nickname: "Alice", recipient_nickname: "Admin", content: "Hey!"}
      changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
      assert changeset.valid?
    end

    test "requires sender_nickname, recipient_nickname, content" do
      changeset = PrivateMessage.changeset(%PrivateMessage{}, %{})
      refute changeset.valid?

      assert %{
               sender_nickname: ["can't be blank"],
               recipient_nickname: ["can't be blank"],
               content: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates sender_nickname max length 16" do
      attrs = %{
        sender_nickname: String.duplicate("a", 17),
        recipient_nickname: "Admin",
        content: "Hi"
      }

      changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
      refute changeset.valid?
    end

    test "validates recipient_nickname max length 16" do
      attrs = %{
        sender_nickname: "Alice",
        recipient_nickname: String.duplicate("a", 17),
        content: "Hi"
      }

      changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
      refute changeset.valid?
    end

    test "validates type inclusion" do
      for valid <- ~w(message action system p2p_invite) do
        attrs = %{
          sender_nickname: "Alice",
          recipient_nickname: "Admin",
          content: "Hi",
          type: valid
        }

        changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
        assert changeset.valid?
      end

      for invalid <- ~w(service error notice) do
        attrs = %{
          sender_nickname: "Alice",
          recipient_nickname: "Admin",
          content: "Hi",
          type: invalid
        }

        changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
        refute changeset.valid?
      end
    end

    test "defaults type to message" do
      attrs = %{sender_nickname: "Alice", recipient_nickname: "Admin", content: "Hi"}
      changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :type) == "message"
    end
  end
end
