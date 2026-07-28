defmodule RetroHexChat.Bots.QueriesPageTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Page

  defp bot(name) do
    {:ok, bot} =
      Queries.create_bot(%{
        name: name,
        nickname: name,
        created_by: "Owner"
      })

    bot
  end

  defp log_events(bot, count) do
    for i <- 1..count do
      {:ok, event} = Queries.log_event(bot.id, "message", "#general", %{"n" => i})
      event
    end
  end

  describe "list_event_logs/2" do
    test "an empty log is an empty page" do
      page = Queries.list_event_logs(bot("EmptyBot#{System.unique_integer([:positive])}").id)

      assert %Page{} = page
      assert page.items == []
      refute page.has_more
    end

    test "one event past the page reports more" do
      b = bot("PageBot#{System.unique_integer([:positive])}")
      log_events(b, 11)

      page = Queries.list_event_logs(b.id, limit: 10)

      assert length(page.items) == 10
      assert page.has_more
    end

    test "a full page with nothing behind it reports nothing more" do
      b = bot("ExactBot#{System.unique_integer([:positive])}")
      log_events(b, 10)

      page = Queries.list_event_logs(b.id, limit: 10)

      assert length(page.items) == 10
      refute page.has_more
    end

    test "the cursor walks the whole log without gaps or repeats" do
      b = bot("WalkBot#{System.unique_integer([:positive])}")
      expected = b |> log_events(25) |> Enum.map(& &1.id) |> Enum.reverse()

      collected =
        Stream.unfold({nil, true}, fn
          {_cursor, false} ->
            nil

          {cursor, true} ->
            opts = if cursor, do: [limit: 10, cursor: cursor], else: [limit: 10]
            page = Queries.list_event_logs(b.id, opts)
            {Enum.map(page.items, & &1.id), {page.next_cursor, page.has_more}}
        end)
        |> Enum.to_list()
        |> List.flatten()

      assert collected == expected
    end

    test "one bot's log never leaks into another's" do
      a = bot("IsolA#{System.unique_integer([:positive])}")
      c = bot("IsolB#{System.unique_integer([:positive])}")
      log_events(a, 3)
      log_events(c, 2)

      assert length(Queries.list_event_logs(a.id).items) == 3
      assert length(Queries.list_event_logs(c.id).items) == 2
    end
  end
end
