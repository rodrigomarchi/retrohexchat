defmodule RetroHexChat.Channels.PinsTest do
  @moduledoc """
  The lines a channel keeps: the rules, the link, what was agreed.

  A pin belongs to the conversation rather than to the message — the same line
  is ordinary everywhere else — so everything here is keyed by channel, and the
  one thing that must never happen is a pin outliving the message it points at.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.Pins
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Chat.Queries

  setup do
    channel = "#pins#{uid()}"
    %{channel: channel, message: message(channel), author: "Pinner"}
  end

  describe "pin/3" do
    test "keeps the line, once", ctx do
      assert {:ok, _pin} = Pins.pin(ctx.channel, ctx.message.id, ctx.author)
      assert {:ok, _same} = Pins.pin(ctx.channel, ctx.message.id, ctx.author)

      assert Pins.count(ctx.channel) == 1
    end

    test "refuses one past the ceiling", ctx do
      for _ <- 1..Pins.max_per_channel() do
        {:ok, _pin} = Pins.pin(ctx.channel, message(ctx.channel).id, ctx.author)
      end

      assert {:error, _reason} = Pins.pin(ctx.channel, message(ctx.channel).id, ctx.author)
      assert Pins.count(ctx.channel) == Pins.max_per_channel()
    end

    test "refuses a message from another channel", ctx do
      elsewhere = message("#other#{uid()}")

      assert {:error, _reason} = Pins.pin(ctx.channel, elsewhere.id, ctx.author)
    end

    test "refuses a message that does not exist", ctx do
      assert {:error, _reason} = Pins.pin(ctx.channel, 0, ctx.author)
    end

    # The pin points at a line. A line that is gone has no pin to point at it,
    # and this is the database's job rather than a cleanup somebody remembers.
    test "deleting the message takes the pin with it", ctx do
      {:ok, _pin} = Pins.pin(ctx.channel, ctx.message.id, ctx.author)

      Repo.delete!(Repo.get!(Message, ctx.message.id))

      assert Pins.count(ctx.channel) == 0
    end
  end

  describe "unpin/2" do
    test "removes it and is quiet about one that was never there", ctx do
      {:ok, _pin} = Pins.pin(ctx.channel, ctx.message.id, ctx.author)

      assert :ok = Pins.unpin(ctx.channel, ctx.message.id)
      assert :ok = Pins.unpin(ctx.channel, ctx.message.id)
      assert Pins.count(ctx.channel) == 0
    end

    test "leaves another channel's pin of the same line alone", ctx do
      other = "#other#{uid()}"
      shared = message(ctx.channel)
      {:ok, _here} = Pins.pin(ctx.channel, shared.id, ctx.author)

      assert :ok = Pins.unpin(other, shared.id)
      assert Pins.count(ctx.channel) == 1
    end
  end

  describe "list/2" do
    test "pages newest first, and says when there is more", ctx do
      for _ <- 1..4, do: {:ok, _} = Pins.pin(ctx.channel, message(ctx.channel).id, ctx.author)

      page = Pins.list(ctx.channel, limit: 2)

      assert length(page.items) == 2
      assert page.has_more
      assert page.next_cursor

      rest = Pins.list(ctx.channel, limit: 2, cursor: page.next_cursor)
      assert length(rest.items) == 2
      refute rest.has_more
    end

    test "carries the line itself, not just its id", ctx do
      {:ok, _pin} = Pins.pin(ctx.channel, ctx.message.id, ctx.author)

      page = Pins.list(ctx.channel)

      assert [entry] = page.items
      assert entry.message_id == ctx.message.id
      assert entry.content == ctx.message.content
      assert entry.author_nickname == ctx.message.author_nickname
      assert entry.pinned_by == ctx.author
    end

    test "a channel with nothing pinned has an empty page", ctx do
      page = Pins.list(ctx.channel)

      assert page.items == []
      refute page.has_more
    end
  end

  defp message(channel) do
    {:ok, message} =
      Queries.insert_message(%{
        channel_name: channel,
        author_nickname: "Speaker",
        content: "a line worth keeping #{uid()}"
      })

    message
  end

  defp uid, do: rem(System.unique_integer([:positive]), 100_000)
end
