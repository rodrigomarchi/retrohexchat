defmodule RetroHexChat.Chat.PrivateMessageTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.PrivateMessage

  @moduletag :unit
  @bold <<0x02>>

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
      for valid <- ~w(message action system p2p_invite p2p_system) do
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

    test "defaults content_format to irc and computes plain_content" do
      attrs = %{
        sender_nickname: "Alice",
        recipient_nickname: "Admin",
        content: "#{@bold}Hi#{@bold}"
      }

      changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :content_format) == "irc"
      assert Ecto.Changeset.get_change(changeset, :plain_content) == "Hi"
    end

    test "accepts markdown content_format and computes visible plain_content" do
      attrs = %{
        sender_nickname: "Alice",
        recipient_nickname: "Admin",
        content: "**release** [notes](https://example.com)",
        content_format: "markdown"
      }

      changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :content_format) == "markdown"
      assert Ecto.Changeset.get_change(changeset, :plain_content) == "release notes"
    end

    test "rejects invalid content_format" do
      attrs = %{
        sender_nickname: "Alice",
        recipient_nickname: "Admin",
        content: "Hi",
        content_format: "html"
      }

      changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
      refute changeset.valid?
      assert %{content_format: [_]} = errors_on(changeset)
    end

    test "does not trust caller-supplied plain_content" do
      attrs = %{
        sender_nickname: "Alice",
        recipient_nickname: "Admin",
        content: "**real**",
        content_format: "markdown",
        plain_content: "spoofed"
      }

      changeset = PrivateMessage.changeset(%PrivateMessage{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :plain_content) == "real"
    end
  end

  describe "reply_changeset/2" do
    test "accepts content_format and computes plain_content" do
      attrs = %{
        sender_nickname: "Alice",
        recipient_nickname: "Admin",
        content: "**I agree**",
        content_format: "markdown",
        reply_to_id: 1,
        reply_to_author: "Admin",
        reply_to_preview: "Original"
      }

      changeset = PrivateMessage.reply_changeset(%PrivateMessage{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :content_format) == "markdown"
      assert Ecto.Changeset.get_change(changeset, :plain_content) == "I agree"
    end
  end

  describe "edit_changeset/2" do
    test "preserves existing content_format and recomputes plain_content" do
      pm = %PrivateMessage{content_format: "markdown"}

      changeset =
        PrivateMessage.edit_changeset(pm, %{
          content: "**Updated**",
          edited_at: DateTime.utc_now()
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :content_format) == "markdown"
      assert Ecto.Changeset.get_change(changeset, :plain_content) == "Updated"
    end
  end
end
