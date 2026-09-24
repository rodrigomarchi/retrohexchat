defmodule RetroHexChat.Chat.QueriesThreadTest do
  @moduledoc """
  Reading a thread out of the replies that already exist.

  A thread is not a column: the root is the message that answers nothing, and
  the thread is what points at it. `Chat.Replies` keeps that pointer one level
  deep, so both questions here — what is in this thread, and how many replies
  does each root on this page have — are one flat query.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Replies
  alias RetroHexChat.Page

  setup do
    %{channel: "#thr#{System.unique_integer([:positive])}"}
  end

  defp root(channel, content \\ "the question") do
    {:ok, message} =
      Queries.insert_message(%{
        channel_name: channel,
        author_nickname: "Ada",
        content: content,
        type: "message"
      })

    message
  end

  defp reply(channel, parent, content) do
    {:ok, attrs} = Replies.attrs(:message, parent.id)

    {:ok, message} =
      Queries.insert_reply_message(
        Map.merge(attrs, %{
          channel_name: channel,
          author_nickname: "Grace",
          content: content,
          type: "message"
        })
      )

    message
  end

  describe "thread_for/2" do
    test "reads oldest first, because a thread is read in the order it happened", ctx do
      parent = root(ctx.channel)
      first = reply(ctx.channel, parent, "one")
      second = reply(ctx.channel, parent, "two")

      page = Queries.thread_for(parent, limit: 10)

      assert Enum.map(page.items, & &1.id) == [first.id, second.id]
      refute page.has_more
    end

    test "pages forward without repeating a line", ctx do
      parent = root(ctx.channel)
      ids = for i <- 1..5, do: reply(ctx.channel, parent, "reply #{i}").id

      first = Queries.thread_for(parent, limit: 2)
      assert Enum.map(first.items, & &1.id) == Enum.take(ids, 2)
      assert first.has_more
      assert first.next_cursor == Enum.at(ids, 1)

      second = Queries.thread_for(parent, limit: 2, cursor: first.next_cursor)
      assert Enum.map(second.items, & &1.id) == Enum.slice(ids, 2, 2)
      assert second.has_more

      third = Queries.thread_for(parent, limit: 2, cursor: second.next_cursor)
      assert Enum.map(third.items, & &1.id) == [List.last(ids)]
      refute third.has_more
    end

    test "a message nobody answered has an empty thread", ctx do
      assert %Page{items: [], has_more: false} = Queries.thread_for(root(ctx.channel), limit: 10)
    end

    # The root going away does not take the conversation with it: the quote is
    # cleared by `reply_quote_updated` and the replies stay where they were.
    test "keeps the replies when the root is deleted", ctx do
      parent = root(ctx.channel)
      kept = reply(ctx.channel, parent, "still here")
      {:ok, _deleted} = Queries.soft_delete(parent, DateTime.utc_now())

      page = Queries.thread_for(parent, limit: 10)

      assert Enum.map(page.items, & &1.id) == [kept.id]
    end

    test "reads a private conversation the same way", ctx do
      {:ok, parent} =
        Queries.insert_private_message(%{
          sender_nickname: "Ada",
          recipient_nickname: "Grace",
          content: "the question"
        })

      {:ok, attrs} = Replies.attrs(:pm, parent.id)

      {:ok, answer} =
        Queries.insert_reply_pm(
          Map.merge(attrs, %{
            sender_nickname: "Grace",
            recipient_nickname: "Ada",
            content: "the answer"
          })
        )

      assert [%{id: id}] = Queries.thread_for(parent, limit: 10).items
      assert id == answer.id
      assert ctx.channel =~ "#thr"
    end
  end

  describe "thread_counts_for_many/2" do
    test "counts a page of roots in one query", ctx do
      roots = for i <- 1..3, do: root(ctx.channel, "question #{i}")
      for r <- Enum.take(roots, 2), do: reply(ctx.channel, r, "an answer")
      reply(ctx.channel, hd(roots), "another answer")

      ids = Enum.map(roots, & &1.id)
      [a, b, c] = ids

      {query_count, counts} =
        count_queries(fn -> Queries.thread_counts_for_many(:message, ids) end)

      assert query_count == 1
      assert counts == %{a => 2, b => 1}
      refute Map.has_key?(counts, c)
    end

    test "says nothing at all when asked about nothing" do
      assert Queries.thread_counts_for_many(:message, []) == %{}
    end

    # The absence that makes the flat thread true: a reply is never a root, so
    # asking about one answers nothing and no counter is ever drawn on it.
    test "a reply is never counted as a root of its own", ctx do
      parent = root(ctx.channel)
      answer = reply(ctx.channel, parent, "an answer")
      reply(ctx.channel, answer, "an answer to the answer")

      counts = Queries.thread_counts_for_many(:message, [parent.id, answer.id])

      assert counts == %{parent.id => 2}
    end

    test "keeps the two kinds of message apart", ctx do
      parent = root(ctx.channel)
      reply(ctx.channel, parent, "an answer")

      assert Queries.thread_counts_for_many(:private_message, [parent.id]) == %{}
    end

    # A deleted reply still draws a row saying it was deleted, so a count that
    # skipped it would open a window with fewer lines than it promised.
    test "counts a reply its author deleted, because the thread still shows it", ctx do
      parent = root(ctx.channel)
      answer = reply(ctx.channel, parent, "an answer")
      {:ok, _deleted} = Queries.soft_delete(answer, DateTime.utc_now())

      assert Queries.thread_counts_for_many(:message, [parent.id]) == %{parent.id => 1}
    end
  end

  defp count_queries(fun) do
    ref = make_ref()
    parent = self()
    handler = "thread-query-count-#{inspect(ref)}"

    :telemetry.attach(
      handler,
      [:retro_hex_chat, :repo, :query],
      fn _event, _measurements, _metadata, _config -> send(parent, {ref, :query}) end,
      nil
    )

    try do
      result = fun.()
      {drain(ref, 0), result}
    after
      :telemetry.detach(handler)
    end
  end

  defp drain(ref, count) do
    receive do
      {^ref, :query} -> drain(ref, count + 1)
    after
      0 -> count
    end
  end
end
