defmodule RetroHexChat.Chat.QueriesPageTest do
  @moduledoc """
  The `Page` contract for the message queries.

  The regression these guard is the one that silently disabled infinite scroll:
  `has_more` used to be computed at the call site from the list *after* the
  ignore-list and cleared-channel filters ran, so a single hidden message on the
  first page ended pagination for that channel forever.
  """
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Page

  defp insert_messages(channel, count, author \\ "User") do
    for i <- 1..count do
      {:ok, msg} =
        Queries.insert_message(%{
          channel_name: channel,
          author_nickname: author,
          content: "Message #{i}",
          type: "message"
        })

      msg
    end
  end

  defp insert_pms(from, to, count) do
    for i <- 1..count do
      {:ok, pm} =
        Queries.insert_private_message(%{
          sender_nickname: from,
          recipient_nickname: to,
          content: "PM #{i}",
          type: "message"
        })

      pm
    end
  end

  describe "list_messages/2 returns a Page" do
    test "an empty channel is an empty page with nothing after it" do
      page = Queries.list_messages("#empty-page")

      assert %Page{} = page
      assert page.items == []
      refute page.has_more
      assert page.next_cursor == nil
    end

    test "exactly one page of messages reports nothing more" do
      insert_messages("#exact", 10)

      page = Queries.list_messages("#exact", limit: 10)

      assert length(page.items) == 10
      refute page.has_more, "a full page with nothing behind it must not claim more"
    end

    test "one message past the page reports more" do
      insert_messages("#one-over", 11)

      page = Queries.list_messages("#one-over", limit: 10)

      assert length(page.items) == 10
      assert page.has_more
    end

    test "the lookahead row is never handed to the caller" do
      messages = insert_messages("#lookahead", 11)
      newest_ten = messages |> Enum.reverse() |> Enum.take(10) |> Enum.map(& &1.id)

      page = Queries.list_messages("#lookahead", limit: 10)

      assert Enum.map(page.items, & &1.id) == newest_ten
    end

    test "the cursor walks the whole history without gaps or repeats" do
      inserted = insert_messages("#walk", 25)
      all_ids = inserted |> Enum.map(& &1.id) |> Enum.reverse()

      {collected, pages} = walk("#walk", 10)

      assert collected == all_ids
      assert pages == 3
    end
  end

  describe "list_private_messages/3 returns a Page" do
    test "an empty conversation is an empty page" do
      page = Queries.list_private_messages("Nobody", "Nowhere")

      assert %Page{} = page
      assert page.items == []
      refute page.has_more
    end

    test "one message past the page reports more" do
      insert_pms("Alice", "Bob", 11)

      page = Queries.list_private_messages("Alice", "Bob", limit: 10)

      assert length(page.items) == 10
      assert page.has_more
    end

    test "the cursor walks the whole conversation" do
      inserted = insert_pms("Carol", "Dave", 25)
      all_ids = inserted |> Enum.map(& &1.id) |> Enum.reverse()

      collected =
        Stream.unfold({nil, true}, fn
          {_cursor, false} ->
            nil

          {cursor, true} ->
            opts = if cursor, do: [limit: 10, cursor: cursor], else: [limit: 10]
            page = Queries.list_private_messages("Carol", "Dave", opts)
            {Enum.map(page.items, & &1.id), {page.next_cursor, page.has_more}}
        end)
        |> Enum.to_list()
        |> List.flatten()

      assert collected == all_ids
    end
  end

  describe "the regression: a filtered page still paginates" do
    test "hiding messages from the page does not end pagination" do
      # A channel where the newest message is from someone the reader ignores.
      # Before Page, `has_more` was `length(visible) == limit`, so this page
      # reported "nothing more" and infinite scroll died for the channel.
      insert_messages("#ignored", 20, "Chatty")

      page = Queries.list_messages("#ignored", limit: 10)
      visible = Page.filter(page, &(&1.author_nickname != "Chatty"))

      assert visible.items == [], "the fixture should hide every row"
      assert visible.has_more, "has_more is a property of the database, not of the visible rows"
      assert visible.next_cursor == page.next_cursor
    end

    test "the cursor survives filtering, so the next page does not re-read hidden rows" do
      insert_messages("#cursor-filter", 20)

      page = Queries.list_messages("#cursor-filter", limit: 10)
      raw_oldest = page.items |> List.last() |> Map.fetch!(:id)

      filtered = Page.filter(page, fn msg -> msg.id != raw_oldest end)

      assert filtered.next_cursor == raw_oldest
    end
  end

  # Pages through a channel, collecting ids in display order.
  defp walk(channel, limit) do
    Stream.unfold({nil, true, 0}, fn
      {_cursor, false, _n} ->
        nil

      {cursor, true, n} ->
        opts = if cursor, do: [limit: limit, cursor: cursor], else: [limit: limit]
        page = Queries.list_messages(channel, opts)
        {{Enum.map(page.items, & &1.id), n + 1}, {page.next_cursor, page.has_more, n + 1}}
    end)
    |> Enum.to_list()
    |> then(fn results ->
      {results |> Enum.flat_map(&elem(&1, 0)), results |> List.last() |> elem(1)}
    end)
  end
end
