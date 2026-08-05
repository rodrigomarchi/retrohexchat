defmodule RetroHexChat.Jobs.ObanHealthTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Bots.Queries, as: BotQueries
  alias RetroHexChat.Jobs.{ObanHealth, RSSPollWorker}

  @moduletag :integration

  test "summarizes queue state and recent failed jobs" do
    now = DateTime.utc_now()

    {:ok, job} =
      %{bot_id: 123, feed_id: "f1"}
      |> RSSPollWorker.new(schedule_in: 0)
      |> Oban.insert()

    attempted_at = DateTime.add(now, -120, :second)

    from(stored in Oban.Job, where: stored.id == ^job.id)
    |> Repo.update_all(
      set: [
        state: "retryable",
        attempted_at: attempted_at,
        scheduled_at: attempted_at,
        errors: [%{"error" => "feed timeout"}]
      ]
    )

    snapshot = ObanHealth.snapshot(filter: "failures", now: now)

    assert snapshot.status == :warning
    assert snapshot.summary.retryable_jobs == 1
    assert snapshot.summary.active_jobs == 1

    assert Enum.any?(snapshot.status_reasons, &(&1 =~ "retry"))

    assert Enum.any?(snapshot.queue_table.rows, fn row ->
             row.queue == "rss" and row.state == "retryable" and row.count == 1
           end)

    assert Enum.any?(snapshot.jobs_table.rows, fn row ->
             row.id == job.id and row.state == "retryable" and row.error == "feed timeout"
           end)
  end

  test "reports RSS feeds missing successor jobs and feeds with poll errors" do
    now = DateTime.utc_now()

    {:ok, bot} =
      BotQueries.create_bot(%{
        name: "ObanHealthBot",
        nickname: "ObanHealthBot",
        created_by: "admin",
        capabilities: %{
          "rss" => %{
            "enabled" => true,
            "feeds" => [
              %{"id" => "f1", "url" => "https://example.com/one.xml", "channel" => "#rss"},
              %{"id" => "f2", "url" => "https://example.com/two.xml", "channel" => "#rss"},
              %{
                "id" => "f3",
                "url" => "https://example.com/three.xml",
                "channel" => "#rss",
                "last_error" => "invalid feed"
              }
            ]
          }
        }
      })

    {:ok, _job} =
      %{bot_id: bot.id, feed_id: "f1"}
      |> RSSPollWorker.new(schedule_in: 60)
      |> Oban.insert()

    snapshot = ObanHealth.snapshot(now: now)

    assert snapshot.summary.rss_feeds == 3
    assert snapshot.summary.rss_missing_jobs == 1
    assert snapshot.summary.rss_feed_errors == 1

    rows_by_feed = Map.new(snapshot.rss_table.rows, &{&1.feed_id, &1})

    assert rows_by_feed["f1"].status == "scheduled"
    assert rows_by_feed["f2"].status == "missing job"
    assert rows_by_feed["f3"].status == "feed error"
  end
end
