defmodule RetroHexChat.Jobs.ObanHealthTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Admin.{BanCache, ServerBans}
  alias RetroHexChat.Bots.Queries, as: BotQueries
  alias RetroHexChat.Chat.LinkPreview.Results, as: LinkPreviewResults
  alias RetroHexChat.Chat.PreferencePersistence
  alias RetroHexChat.Chat.Schemas.IgnoreListEntry

  alias RetroHexChat.Jobs.{
    BotEventLogWorker,
    BotScheduledMessageWorker,
    ObanHealth,
    RSSPollWorker,
    ServerBanExpiryWorker
  }

  alias RetroHexChat.Services.NickServ

  @moduletag :integration

  setup do
    on_exit(fn -> BanCache.remove("HealthBan") end)
    :ok
  end

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

    filtered =
      ObanHealth.snapshot(filter: "all", queue: "rss", worker: "RSSPollWorker", now: now)

    assert filtered.job_queue_filter == "rss"
    assert filtered.job_worker_filter == "RSSPollWorker"
    assert Enum.map(filtered.jobs_table.rows, & &1.id) == [job.id]

    empty = ObanHealth.snapshot(filter: "all", queue: "bots", worker: "RSSPollWorker", now: now)

    assert empty.jobs_table.rows == []
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

  test "reports bot schedule successor coverage and event log backlog" do
    now = DateTime.utc_now()

    {:ok, bot} =
      BotQueries.create_bot(%{
        name: "ObanSchedBot",
        nickname: "ObanSchedBot",
        created_by: "admin",
        capabilities: %{
          "scheduler" => %{
            "enabled" => true,
            "schedules" => [
              %{
                "id" => "sched1",
                "type" => "interval",
                "interval_min" => 5,
                "channel" => "#bots",
                "message" => "tick",
                "last_fired" => nil
              },
              %{
                "id" => "sched2",
                "type" => "daily",
                "time" => "09:00",
                "channel" => "#bots",
                "message" => "standup",
                "last_fired" => nil
              }
            ]
          }
        }
      })

    {:ok, _schedule_job} =
      %{bot_id: bot.id, schedule_id: "sched1"}
      |> BotScheduledMessageWorker.new(schedule_in: 300)
      |> Oban.insert()

    {:ok, event_job} =
      %{
        bot_id: bot.id,
        event_type: "message_response",
        channel: "#bots",
        metadata: %{}
      }
      |> BotEventLogWorker.new()
      |> Oban.insert()

    attempted_at = DateTime.add(now, -90, :second)

    from(stored in Oban.Job, where: stored.id == ^event_job.id)
    |> Repo.update_all(
      set: [
        state: "retryable",
        attempted_at: attempted_at,
        scheduled_at: attempted_at,
        errors: [%{"error" => "insert timeout"}]
      ]
    )

    snapshot = ObanHealth.snapshot(now: now)

    assert snapshot.summary.bot_schedules == 2
    assert snapshot.summary.bot_schedule_missing_jobs == 1
    assert snapshot.summary.bot_schedule_failures == 0
    assert snapshot.summary.bot_event_log_jobs == 1
    assert snapshot.summary.bot_event_log_active == 1
    assert snapshot.summary.bot_event_log_failures == 1

    rows_by_schedule = Map.new(snapshot.bot_schedule_table.rows, &{&1.schedule_id, &1})

    assert rows_by_schedule["sched1"].status == "scheduled"
    assert rows_by_schedule["sched2"].status == "missing job"
    assert rows_by_schedule["sched2"].next_delay_ms > 0

    [event_log_row] = snapshot.bot_event_log_table.rows

    assert event_log_row.state == "retryable"
    assert event_log_row.status == "failed"
    assert event_log_row.count == 1
    assert event_log_row.last_error == "insert timeout"

    assert Enum.any?(snapshot.status_reasons, &(&1 =~ "bot schedules"))
    assert Enum.any?(snapshot.status_reasons, &(&1 =~ "bot event log"))
  end

  test "reports maintenance sweep state and pending server ban work" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -120, :second)

    {:ok, _ban} = ServerBans.ban("HealthBan", "Admin", "expired", past)
    {:ok, _message} = NickServ.register("HealthIgnore", "pass123")

    %IgnoreListEntry{}
    |> IgnoreListEntry.changeset(%{
      owner_nickname: "HealthIgnore",
      ignored_nickname: "Expired",
      ignore_type: "all",
      expires_at: past
    })
    |> Repo.insert!()

    {:ok, job} =
      %{}
      |> ServerBanExpiryWorker.new(schedule_in: 0)
      |> Oban.insert()

    attempted_at = DateTime.add(now, -60, :second)

    from(stored in Oban.Job, where: stored.id == ^job.id)
    |> Repo.update_all(
      set: [
        state: "retryable",
        attempted_at: attempted_at,
        scheduled_at: attempted_at,
        errors: [%{"error" => "database timeout"}]
      ]
    )

    snapshot = ObanHealth.snapshot(now: now)

    assert snapshot.summary.maintenance_sweeps == 10
    assert snapshot.summary.maintenance_failures == 1
    assert snapshot.summary.maintenance_pending_work == 2
    assert Enum.any?(snapshot.status_reasons, &(&1 =~ "maintenance"))

    rows_by_sweep = Map.new(snapshot.maintenance_table.rows, &{&1.sweep, &1})
    row = Map.fetch!(rows_by_sweep, "Server ban expiry")

    assert row.sweep == "Server ban expiry"
    assert row.queue == "maintenance"
    assert row.worker == "ServerBanExpiryWorker"
    assert row.status == "failed"
    assert row.active_jobs == 1
    assert row.failure_jobs == 1
    assert row.pending_work == 1
    assert row.last_error == "database timeout"

    channel_row = Map.fetch!(rows_by_sweep, "Registered channel expiry")

    assert channel_row.queue == "maintenance"
    assert channel_row.worker == "RegisteredChannelExpiryWorker"
    assert channel_row.status == "never run"
    assert channel_row.pending_work == 0

    nick_row = Map.fetch!(rows_by_sweep, "Registered nick expiry")

    assert nick_row.queue == "maintenance"
    assert nick_row.worker == "RegisteredNickExpiryWorker"
    assert nick_row.status == "never run"
    assert nick_row.pending_work == 0

    attachment_row = Map.fetch!(rows_by_sweep, "Attachment orphan cleanup")

    assert attachment_row.queue == "maintenance"
    assert attachment_row.worker == "AttachmentOrphanCleanupWorker"
    assert attachment_row.status == "never run"
    assert attachment_row.pending_work == 0

    device_row = Map.fetch!(rows_by_sweep, "Trusted device expiry")

    assert device_row.queue == "maintenance"
    assert device_row.worker == "TrustedDeviceExpiryWorker"
    assert device_row.status == "never run"
    assert device_row.pending_work == 0

    session_row = Map.fetch!(rows_by_sweep, "Chat device session cleanup")

    assert session_row.queue == "maintenance"
    assert session_row.worker == "ChatDeviceSessionCleanupWorker"
    assert session_row.status == "never run"
    assert session_row.pending_work == 0

    runtime_row = Map.fetch!(rows_by_sweep, "Runtime stale cleanup")

    assert runtime_row.queue == "maintenance"
    assert runtime_row.worker == "RuntimeStaleCleanupWorker"
    assert runtime_row.status == "never run"
    assert runtime_row.pending_work == 0

    channel_mute_row = Map.fetch!(rows_by_sweep, "Channel mute expiry")

    assert channel_mute_row.queue == "maintenance"
    assert channel_mute_row.worker == "ChannelMuteExpiryWorker"
    assert channel_mute_row.status == "never run"
    assert channel_mute_row.pending_work == 0

    global_mute_row = Map.fetch!(rows_by_sweep, "Global mute expiry")

    assert global_mute_row.queue == "maintenance"
    assert global_mute_row.worker == "GlobalMuteExpiryWorker"
    assert global_mute_row.status == "never run"
    assert global_mute_row.pending_work == 0

    ignore_row = Map.fetch!(rows_by_sweep, "Ignore expired cleanup")

    assert ignore_row.queue == "maintenance"
    assert ignore_row.worker == "IgnoreExpiredCleanupWorker"
    assert ignore_row.status == "pending work"
    assert ignore_row.pending_work == 1
  end

  test "reports link preview cache state" do
    now = DateTime.utc_now()

    {:ok, _ready} =
      LinkPreviewResults.record_success("https://example.com/ready", "Ready",
        now: DateTime.add(now, -60, :second),
        attempt: 1
      )

    {:ok, _pending} =
      LinkPreviewResults.ensure_pending("https://example.com/pending", now: now)

    {:ok, _expired_failed} =
      LinkPreviewResults.record_failure("https://example.com/missing", {:http_status, 404},
        now: DateTime.add(now, -600, :second),
        attempt: 1
      )

    snapshot = ObanHealth.snapshot(now: now)

    assert snapshot.summary.link_previews == 3
    assert snapshot.summary.link_preview_pending == 1
    assert snapshot.summary.link_preview_failed == 1
    assert snapshot.summary.link_preview_expired == 1

    rows_by_status = Map.new(snapshot.link_preview_table.rows, &{&1.status, &1})

    assert rows_by_status["ready"].count == 1
    assert rows_by_status["pending"].count == 1
    assert rows_by_status["failed"].count == 1
    assert rows_by_status["failed"].expired == 1
  end

  test "reports preference persistence backlog state" do
    owner = "HealthPrefs"
    {:ok, _message} = NickServ.register(owner, "pass123")

    assert :ok =
             PreferencePersistence.enqueue(owner, :input_history, %{
               entries: ["draft"],
               recent_commands: []
             })

    snapshot = ObanHealth.snapshot(now: DateTime.utc_now())

    assert snapshot.summary.persistence_requests == 1
    assert snapshot.summary.persistence_pending == 1
    assert snapshot.summary.persistence_failed == 0
    assert snapshot.summary.persistence_payload_bytes > 0

    [row] = snapshot.persistence_table.rows

    assert row.preference_type == "input_history"
    assert row.status == "pending"
    assert row.count == 1
    assert row.payload_size_bytes > 0
  end
end
