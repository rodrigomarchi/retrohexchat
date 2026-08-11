defmodule RetroHexChat.Chat.RepliesTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :unit

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Replies
  alias RetroHexChat.Chat.Service

  defp channel_message(content) do
    {:ok, message} =
      Queries.insert_message(%{
        channel_name: "#lobby",
        author_nickname: "Ada",
        content: content,
        type: "message"
      })

    message
  end

  defp private_message(content) do
    {:ok, pm} =
      Queries.insert_private_message(%{
        sender_nickname: "Ada",
        recipient_nickname: "Grace",
        content: content
      })

    pm
  end

  test "a channel reply quotes who wrote the message it answers" do
    parent = channel_message("the original")

    assert {:ok, attrs} = Replies.attrs(:message, parent.id)
    assert attrs.reply_to_id == parent.id
    assert attrs.reply_to_author == "Ada"
    assert attrs.reply_to_preview =~ "the original"
  end

  # The author is read the same way for both, which is the whole reason this is
  # one function: the two schemas spell the column differently and
  # `Chat.Authorship` is what knows that.
  test "a private reply quotes its sender as the author" do
    parent = private_message("the original")

    assert {:ok, attrs} = Replies.attrs(:pm, parent.id)
    assert attrs.reply_to_author == "Ada"
  end

  test "a parent that is not there is reported, not decided" do
    assert Replies.attrs(:message, 999_999) == :not_found
    assert Replies.attrs(:pm, 999_999) == :not_found
  end

  # The two callers disagree on purpose, and nothing else records that they do.
  describe "what each caller does with :not_found" do
    test "a private message refuses to be sent without the quote it claims" do
      assert {:error, _reason} =
               Service.send_private_message("Ada", "Grace", "Reply", "message",
                 reply_to_id: 999_999
               )
    end

    test "a channel message is sent anyway, without the quote" do
      channel = "#rep#{System.unique_integer([:positive])}"
      {:ok, pid} = ChannelSupervisor.start_child(channel)
      on_exit(fn -> if Process.alive?(pid), do: ChannelSupervisor.stop_child(pid) end)
      {:ok, _state} = Server.join(channel, "Ada")

      assert {:ok, id} = Server.send_message(channel, "Ada", "Reply", reply_to_id: 999_999)

      assert %{content: "Reply", reply_to_id: nil} = Queries.get_message(id)
    end
  end
end
