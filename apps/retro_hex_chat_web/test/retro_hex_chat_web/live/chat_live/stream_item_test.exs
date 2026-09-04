defmodule RetroHexChatWeb.ChatLive.StreamItemTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.ChatLive.StreamItem

  @at ~U[2026-07-08 12:00:00Z]

  defp channel_message(extra \\ %{}) do
    Map.merge(
      %{
        id: 1,
        author_nickname: "Ada",
        content: "hello",
        type: "message",
        inserted_at: @at
      },
      extra
    )
  end

  defp private_message(extra \\ %{}) do
    Map.merge(
      %{
        id: 1,
        sender_nickname: "Ada",
        content: "hello",
        type: "message",
        inserted_at: @at
      },
      extra
    )
  end

  describe "either kind can arrive from the database or from a broadcast" do
    # A channel message readable only in its database spelling forces a message
    # arriving live to be assembled by hand in the shape the broadcast happens to
    # have. Reading both spellings is what lets one builder serve both arrivals,
    # as it does for private messages.
    test "a channel message reads the same from either spelling" do
      from_database = channel_message()

      from_broadcast = %{
        id: 1,
        author: "Ada",
        content: "hello",
        type: "message",
        timestamp: @at,
        channel: "#lobby"
      }

      assert StreamItem.from_message(from_broadcast) == StreamItem.from_message(from_database)
    end

    test "the conversation a broadcast names is not part of the row" do
      row = StreamItem.from_message(%{id: 1, author: "Ada", content: "hi", timestamp: @at})

      refute Map.has_key?(row, :channel)
    end

    test "a broadcast that says nothing about a reply produces no reply keys" do
      row =
        StreamItem.from_message(%{
          id: 1,
          author: "Ada",
          content: "hi",
          timestamp: @at,
          reply_to_id: nil,
          reply_to_author: nil,
          reply_to_preview: nil
        })

      refute Map.has_key?(row, :reply_to_id)
      refute Map.has_key?(row, :reply_to_author)
    end
  end

  describe "the shape both conversations produce" do
    test "a channel message and a private message become the same row" do
      assert StreamItem.from_message(channel_message()) ==
               StreamItem.from_private_message(private_message())
    end

    test "the row carries the keys the renderer reads" do
      item = StreamItem.from_message(channel_message())

      assert %{
               id: 1,
               author: "Ada",
               content: "hello",
               content_format: "irc",
               type: :message,
               timestamp: @at,
               attachments: []
             } = item
    end

    test "a format the source did not persist reads as irc" do
      assert %{content_format: "irc"} = StreamItem.from_message(channel_message())
      assert %{content_format: "irc"} = StreamItem.from_private_message(private_message())
    end

    test "a persisted format is kept" do
      assert %{content_format: "markdown"} =
               StreamItem.from_message(channel_message(%{content_format: "markdown"}))

      assert %{content_format: "markdown"} =
               StreamItem.from_private_message(private_message(%{content_format: "markdown"}))
    end

    test "a type that no longer renders falls back rather than reaching the row" do
      assert %{type: :message} =
               StreamItem.from_message(channel_message(%{type: "space_invite"}))

      assert %{type: :message} =
               StreamItem.from_private_message(private_message(%{type: "space_invite"}))
    end

    test "a type the source omits reads as a plain message" do
      assert %{type: :message} =
               StreamItem.from_private_message(Map.delete(private_message(), :type))
    end
  end

  describe "optional fields" do
    test "a field the source omits is absent, not nil" do
      item = StreamItem.from_message(channel_message())

      for key <- [
            :reply_to_id,
            :reply_to_author,
            :reply_to_preview,
            :plain_content,
            :edited_at,
            :deleted_at
          ] do
        refute Map.has_key?(item, key), "expected #{key} to be absent"
      end
    end

    test "a field the source carries is kept, on both kinds" do
      extra = %{plain_content: "Markdown", edited_at: @at}

      assert %{plain_content: "Markdown", edited_at: @at} =
               StreamItem.from_message(channel_message(extra))

      assert %{plain_content: "Markdown", edited_at: @at} =
               StreamItem.from_private_message(private_message(extra))
    end

    test "a reply quote whose author is unknown does not invent one" do
      item = StreamItem.from_private_message(private_message(%{reply_to_id: 7}))

      assert item.reply_to_id == 7
      refute Map.has_key?(item, :reply_to_author)
    end
  end

  describe "a private message that arrived over the wire" do
    test "the broadcast spelling of the author is normalized" do
      assert %{author: "Ada"} =
               StreamItem.from_private_message(%{
                 id: 1,
                 sender: "Ada",
                 content: "hello",
                 type: "message",
                 timestamp: @at
               })
    end

    test "the broadcast spelling of the moment is normalized" do
      assert %{timestamp: @at} =
               StreamItem.from_private_message(%{
                 id: 1,
                 sender: "Ada",
                 content: "hello",
                 type: "message",
                 timestamp: @at
               })
    end
  end

  describe "attachments" do
    test "a source with none carries an empty list" do
      assert %{attachments: []} = StreamItem.from_message(channel_message())
    end

    test "an unloaded association is not mistaken for attachments" do
      item =
        StreamItem.from_message(channel_message(%{attachments: %Ecto.Association.NotLoaded{}}))

      assert item.attachments == []
    end

    test "an attachments key holding nothing usable stays an empty list" do
      assert %{attachments: []} =
               StreamItem.from_private_message(private_message(%{attachments: nil}))
    end

    test "prebuilt payloads pass through" do
      payload = %{id: 9, filename: "a.png"}

      assert %{attachments: [^payload]} =
               StreamItem.from_message(channel_message(%{attachments: [payload]}))
    end
  end
end
