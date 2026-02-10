defmodule RetroHexChat.Chat.QueriesPerformanceTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :performance
  @moduletag timeout: 300_000

  alias RetroHexChat.Chat.{Message, Queries}
  alias RetroHexChat.Repo

  describe "pagination performance with 100k messages" do
    @tag timeout: 300_000
    test "cursor pagination query returns in under 100ms" do
      channel = "#perf-test-#{System.unique_integer([:positive])}"

      # Seed 100k messages using insert_all for speed.
      # The messages table has: channel_name, author_nickname, content, type, inserted_at
      # (no updated_at column).
      now = DateTime.utc_now()

      messages =
        for i <- 1..100_000 do
          %{
            channel_name: channel,
            author_nickname: "user_#{rem(i, 100)}",
            content: "Performance test message number #{i}",
            type: "message",
            inserted_at: now
          }
        end

      # Insert in batches of 10_000 to avoid oversized queries
      messages
      |> Enum.chunk_every(10_000)
      |> Enum.each(fn batch ->
        Repo.insert_all(Message, batch)
      end)

      # Benchmark: The first page (newest 50)
      {time_us, first_page} =
        :timer.tc(fn -> Queries.list_messages(channel, limit: 50) end)

      assert length(first_page) == 50
      time_ms = time_us / 1000
      assert time_ms < 100, "First page query took #{time_ms}ms, expected < 100ms"

      # Cursor-based pagination using a middle ID
      last_on_page = List.last(first_page)

      {time_us2, second_page} =
        :timer.tc(fn ->
          Queries.list_messages(channel, limit: 50, before_id: last_on_page.id)
        end)

      assert length(second_page) == 50
      time_ms2 = time_us2 / 1000
      assert time_ms2 < 100, "Cursor pagination query took #{time_ms2}ms, expected < 100ms"

      # Deep pagination (near the beginning of messages)
      # Get the very first (oldest) message's ID by going deep
      deep_cursor = List.last(second_page).id

      {time_us3, deep_page} =
        :timer.tc(fn ->
          Queries.list_messages(channel, limit: 50, before_id: deep_cursor)
        end)

      assert length(deep_page) == 50
      time_ms3 = time_us3 / 1000
      assert time_ms3 < 100, "Deep pagination query took #{time_ms3}ms, expected < 100ms"
    end
  end
end
