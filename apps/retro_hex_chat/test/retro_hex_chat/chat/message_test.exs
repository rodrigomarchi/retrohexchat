defmodule RetroHexChat.Chat.MessageTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.Message

  @moduletag :unit

  describe "changeset/2" do
    test "valid attrs produce a valid changeset" do
      attrs = %{channel_name: "#lobby", author_nickname: "Alice", content: "Hello!"}
      changeset = Message.changeset(%Message{}, attrs)
      assert changeset.valid?
    end

    test "requires channel_name, author_nickname, content" do
      changeset = Message.changeset(%Message{}, %{})
      refute changeset.valid?

      assert %{
               channel_name: ["can't be blank"],
               author_nickname: ["can't be blank"],
               content: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates channel_name max length 50" do
      attrs = %{
        channel_name: String.duplicate("a", 51),
        author_nickname: "Alice",
        content: "Hi"
      }

      changeset = Message.changeset(%Message{}, attrs)
      refute changeset.valid?
      assert %{channel_name: [_]} = errors_on(changeset)
    end

    test "validates author_nickname max length 16" do
      attrs = %{channel_name: "#lobby", author_nickname: String.duplicate("a", 17), content: "Hi"}
      changeset = Message.changeset(%Message{}, attrs)
      refute changeset.valid?
      assert %{author_nickname: [_]} = errors_on(changeset)
    end

    test "validates type inclusion" do
      for valid_type <- ~w(message action system service error) do
        attrs = %{
          channel_name: "#lobby",
          author_nickname: "Alice",
          content: "Hi",
          type: valid_type
        }

        changeset = Message.changeset(%Message{}, attrs)
        assert changeset.valid?, "Expected #{valid_type} to be valid"
      end
    end

    test "rejects invalid type" do
      attrs = %{
        channel_name: "#lobby",
        author_nickname: "Alice",
        content: "Hi",
        type: "invalid"
      }

      changeset = Message.changeset(%Message{}, attrs)
      refute changeset.valid?
      assert %{type: [_]} = errors_on(changeset)
    end

    test "defaults type to message" do
      attrs = %{channel_name: "#lobby", author_nickname: "Alice", content: "Hi"}
      changeset = Message.changeset(%Message{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :type) == "message"
    end
  end

  describe "reply_changeset/2" do
    test "valid reply with all fields" do
      attrs = %{
        channel_name: "#lobby",
        author_nickname: "Alice",
        content: "I agree!",
        reply_to_id: 42,
        reply_to_author: "Mario",
        reply_to_preview: "eu acho que devíamos usar Elixir"
      }

      changeset = Message.reply_changeset(%Message{}, attrs)
      assert changeset.valid?
    end

    test "requires reply_to_author and reply_to_preview when reply_to_id is set" do
      attrs = %{
        channel_name: "#lobby",
        author_nickname: "Alice",
        content: "I agree!",
        reply_to_id: 42
      }

      changeset = Message.reply_changeset(%Message{}, attrs)
      refute changeset.valid?
      assert %{reply_to_author: _, reply_to_preview: _} = errors_on(changeset)
    end

    test "valid without reply fields (normal message)" do
      attrs = %{channel_name: "#lobby", author_nickname: "Alice", content: "Hello!"}
      changeset = Message.reply_changeset(%Message{}, attrs)
      assert changeset.valid?
    end

    test "validates reply_to_preview max 100 chars" do
      attrs = %{
        channel_name: "#lobby",
        author_nickname: "Alice",
        content: "reply",
        reply_to_id: 1,
        reply_to_author: "Mario",
        reply_to_preview: String.duplicate("a", 101)
      }

      changeset = Message.reply_changeset(%Message{}, attrs)
      refute changeset.valid?
      assert %{reply_to_preview: _} = errors_on(changeset)
    end
  end

  describe "edit_changeset/2" do
    test "valid edit with content and edited_at" do
      changeset =
        Message.edit_changeset(%Message{}, %{
          content: "Updated content",
          edited_at: DateTime.utc_now()
        })

      assert changeset.valid?
    end

    test "requires content and edited_at" do
      changeset = Message.edit_changeset(%Message{}, %{})
      refute changeset.valid?
      assert %{content: _, edited_at: _} = errors_on(changeset)
    end
  end

  describe "delete_changeset/1" do
    test "valid delete with deleted_at" do
      changeset = Message.delete_changeset(%Message{}, %{deleted_at: DateTime.utc_now()})
      assert changeset.valid?
    end

    test "requires deleted_at" do
      changeset = Message.delete_changeset(%Message{}, %{})
      refute changeset.valid?
      assert %{deleted_at: _} = errors_on(changeset)
    end
  end
end
