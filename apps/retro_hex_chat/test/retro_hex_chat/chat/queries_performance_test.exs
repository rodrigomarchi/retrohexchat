defmodule RetroHexChat.Chat.QueriesPerformanceTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :performance
  @moduletag timeout: 300_000

  alias RetroHexChat.Chat.{Message, Queries}
  alias RetroHexChat.Repo

  # A channel's history is paged by cursor on an id index, so a page costs
  # the same at message 50 and at message 99,950. What decides
  # that is the plan Postgres picks for the query list_messages/2 sends, not
  # how long it took on whatever else the machine was running: a page that
  # walks the table, or sorts it, is the regression this guards.
  describe "pagination over 100k messages in ten channels" do
    @tag timeout: 300_000
    test "every page is read from the channel's index, never by scanning the table" do
      prefix = "#perf-test-#{System.unique_integer([:positive])}"
      channel = "#{prefix}-0"
      now = DateTime.utc_now()

      # One channel among ten, its messages interleaved with the others' the
      # way a busy server writes them: reading the newest ids and filtering
      # would walk nine foreign messages for every one of this channel's.
      1..100_000
      |> Enum.map(fn i ->
        %{
          channel_name: "#{prefix}-#{rem(i, 10)}",
          author_nickname: "user_#{rem(i, 100)}",
          content: "Performance test message number #{i}",
          type: "message",
          inserted_at: now
        }
      end)
      |> Enum.chunk_every(10_000)
      |> Enum.each(&Repo.insert_all(Message, &1))

      # The planner chooses by the table's statistics; without fresh ones a
      # table it believes small is scanned whatever the indexes say.
      Repo.query!("ANALYZE messages")

      {first_page, first_plan} = planned(fn -> Queries.list_messages(channel, limit: 50) end)
      assert length(first_page.items) == 50
      assert_indexed(first_plan)

      cursor = List.last(first_page.items).id

      {second_page, second_plan} =
        planned(fn -> Queries.list_messages(channel, limit: 50, cursor: cursor) end)

      assert length(second_page.items) == 50
      assert Enum.all?(second_page.items, &(&1.id < cursor))
      assert_indexed(second_plan)
    end
  end

  # Runs `fun` and returns its result with the plan of the query it sent to
  # the messages table, as Postgres would execute it.
  defp planned(fun) do
    parent = self()
    handler = "queries-performance-#{System.unique_integer([:positive])}"

    # Every query anybody in the VM sends reaches this handler, and a handler
    # that raises on one is detached for good: matching only the messages
    # query in the head made the first foreign query — another test, a
    # background job — switch it off, and the page's query never arrived.
    :ok =
      :telemetry.attach(
        handler,
        [:retro_hex_chat, :repo, :query],
        fn _event, _measurements, metadata, _ ->
          if self() == parent and metadata[:source] == "messages" do
            send(parent, {:messages_query, metadata.query, metadata.params})
          end
        end,
        nil
      )

    result =
      try do
        fun.()
      after
        :telemetry.detach(handler)
      end

    assert_received {:messages_query, sql, params}
    %{rows: [[[plan]]]} = Repo.query!("EXPLAIN (FORMAT JSON) " <> sql, params)
    {result, plan["Plan"]}
  end

  defp assert_indexed(plan) do
    nodes = plan_nodes(plan)
    types = Enum.map(nodes, & &1["Node Type"])

    refute "Seq Scan" in types, "the page scanned the table: #{inspect(types)}"

    refute "Sort" in types,
           "the page sorted rows instead of reading them in order: #{inspect(types)}"

    assert Enum.any?(nodes, &index_read?/1),
           "the page read messages without an index: #{inspect(types)}"
  end

  # Which index is the planner's call: with a channel this size it reads the
  # primary key backwards and filters, a few hundred rows for a page, and a
  # small channel gets its (channel_name, id) range. Either is a page read in
  # order; a scan or a sort is the whole channel read for fifty lines.
  defp index_read?(node) do
    node["Node Type"] in ["Index Scan", "Index Scan Backward", "Index Only Scan"] and
      node["Relation Name"] == "messages"
  end

  defp plan_nodes(plan), do: [plan | Enum.flat_map(plan["Plans"] || [], &plan_nodes/1)]
end
