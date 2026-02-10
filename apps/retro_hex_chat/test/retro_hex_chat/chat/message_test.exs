defmodule RetroHexChat.Chat.MessageTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.Message

  @moduletag :unit

  describe "changeset/2" do
    test "valid attrs produce a valid changeset" do
      attrs = %{channel_name: "#lobby", author_nickname: "Rodrigo", content: "Hello!"}
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
        author_nickname: "Rodrigo",
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
          author_nickname: "Rodrigo",
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
        author_nickname: "Rodrigo",
        content: "Hi",
        type: "invalid"
      }

      changeset = Message.changeset(%Message{}, attrs)
      refute changeset.valid?
      assert %{type: [_]} = errors_on(changeset)
    end

    test "defaults type to message" do
      attrs = %{channel_name: "#lobby", author_nickname: "Rodrigo", content: "Hi"}
      changeset = Message.changeset(%Message{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :type) == "message"
    end
  end
end
