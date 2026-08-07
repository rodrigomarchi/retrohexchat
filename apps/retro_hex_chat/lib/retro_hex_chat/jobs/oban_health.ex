defmodule RetroHexChat.Jobs.ObanHealth do
  @moduledoc """
  Read-only health snapshot for the Oban runtime.

  The application only schedules durable background work through Oban, so an
  administrator needs two views at once: generic queue health and domain
  contracts such as successor coverage, maintenance sweeps and durable
  persistence/fetch backlogs.
  This module owns both readings and returns them as `Table` values so
  the web surface never has to know Oban's schema.
  """

  import Ecto.Query

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Admin.{GlobalMutes, ServerBans}
  alias RetroHexChat.Bots.Capabilities.Scheduler
  alias RetroHexChat.Bots.{Feeds, Queries}
  alias RetroHexChat.Channels.Mutes, as: ChannelMutes
  alias RetroHexChat.Chat.{Attachments, IgnoreList}
  alias RetroHexChat.Chat.PreferencePersistence

  alias RetroHexChat.Jobs.{
    AttachmentOrphanCleanupWorker,
    BotEventLogWorker,
    BotScheduledMessageWorker,
    ChannelMuteExpiryWorker,
    ChatDeviceSessionCleanupWorker,
    GlobalMuteExpiryWorker,
    IgnoreExpiredCleanupWorker,
    RegisteredChannelExpiryWorker,
    RegisteredNickExpiryWorker,
    RSSPollWorker,
    RuntimeStaleCleanupWorker,
    ServerBanExpiryWorker,
    TrustedDeviceExpiryWorker
  }

  alias RetroHexChat.Repo
  alias RetroHexChat.RuntimeStaleCleanup
  alias RetroHexChat.Scraper.Store, as: ScraperStore
  alias RetroHexChat.Services.{ChanExpiry, NickExpiry}
  alias RetroHexChat.Table

  @default_filter "active"
  @recent_limit 30
  @available_lag_warning_ms 60_000
  @available_lag_critical_ms 300_000
  @executing_age_warning_ms 300_000
  @executing_age_critical_ms 600_000

  @active_states ~w(available scheduled executing retryable suspended)
  @failure_states ~w(retryable discarded cancelled)
  @rss_incomplete_states ~w(available scheduled executing retryable suspended)

  @maintenance_sweeps [
    %{
      id: "server_ban_expiry",
      label: "Server ban expiry",
      queue: "maintenance",
      worker: ServerBanExpiryWorker
    },
    %{
      id: "registered_channel_expiry",
      label: "Registered channel expiry",
      queue: "maintenance",
      worker: RegisteredChannelExpiryWorker
    },
    %{
      id: "registered_nick_expiry",
      label: "Registered nick expiry",
      queue: "maintenance",
      worker: RegisteredNickExpiryWorker
    },
    %{
      id: "attachment_orphan_cleanup",
      label: "Attachment orphan cleanup",
      queue: "maintenance",
      worker: AttachmentOrphanCleanupWorker
    },
    %{
      id: "trusted_device_expiry",
      label: "Trusted device expiry",
      queue: "maintenance",
      worker: TrustedDeviceExpiryWorker
    },
    %{
      id: "chat_device_session_cleanup",
      label: "Chat device session cleanup",
      queue: "maintenance",
      worker: ChatDeviceSessionCleanupWorker
    },
    %{
      id: "runtime_stale_cleanup",
      label: "Runtime stale cleanup",
      queue: "maintenance",
      worker: RuntimeStaleCleanupWorker
    },
    %{
      id: "channel_mute_expiry",
      label: "Channel mute expiry",
      queue: "maintenance",
      worker: ChannelMuteExpiryWorker
    },
    %{
      id: "global_mute_expiry",
      label: "Global mute expiry",
      queue: "maintenance",
      worker: GlobalMuteExpiryWorker
    },
    %{
      id: "ignore_expired_cleanup",
      label: "Ignore expired cleanup",
      queue: "maintenance",
      worker: IgnoreExpiredCleanupWorker
    }
  ]

  @job_filters [
    %{id: "active", label: "Active", states: @active_states},
    %{id: "failures", label: "Failures", states: @failure_states},
    %{id: "discarded", label: "Discarded", states: ~w(discarded cancelled)},
    %{id: "all", label: "All", states: nil}
  ]

  defmodule Snapshot do
    @moduledoc "One read-only Oban health reading."

    @type status :: :healthy | :warning | :critical

    @type config :: %{
            name: String.t(),
            node: String.t() | nil,
            repo: String.t() | nil,
            engine: String.t() | nil,
            notifier: String.t() | nil,
            peer: String.t() | nil,
            prefix: String.t() | nil,
            testing: String.t() | nil,
            plugins: [String.t()],
            queues: [map()]
          }

    @type summary :: %{
            running?: boolean(),
            configured_queues: non_neg_integer(),
            queue_concurrency: non_neg_integer(),
            total_jobs: non_neg_integer(),
            active_jobs: non_neg_integer(),
            executing_jobs: non_neg_integer(),
            retryable_jobs: non_neg_integer(),
            discarded_jobs: non_neg_integer(),
            cancelled_jobs: non_neg_integer(),
            rss_feeds: non_neg_integer(),
            rss_missing_jobs: non_neg_integer(),
            rss_feed_errors: non_neg_integer(),
            bot_schedules: non_neg_integer(),
            bot_schedule_missing_jobs: non_neg_integer(),
            bot_schedule_failures: non_neg_integer(),
            bot_event_log_jobs: non_neg_integer(),
            bot_event_log_active: non_neg_integer(),
            bot_event_log_failures: non_neg_integer(),
            maintenance_sweeps: non_neg_integer(),
            maintenance_failures: non_neg_integer(),
            maintenance_pending_work: non_neg_integer(),
            scraped_pages: non_neg_integer(),
            scraped_page_pending: non_neg_integer(),
            scraped_page_retrying: non_neg_integer(),
            scraped_page_final_failures: non_neg_integer(),
            scraped_page_failed: non_neg_integer(),
            scraped_page_expired: non_neg_integer(),
            persistence_requests: non_neg_integer(),
            persistence_pending: non_neg_integer(),
            persistence_failed: non_neg_integer(),
            persistence_payload_bytes: non_neg_integer(),
            max_available_lag_ms: non_neg_integer() | nil,
            max_executing_age_ms: non_neg_integer() | nil,
            last_completed_at: DateTime.t() | nil,
            last_discarded_at: DateTime.t() | nil
          }

    @type t :: %__MODULE__{
            taken_at: DateTime.t(),
            status: status(),
            status_reasons: [String.t()],
            job_filter: String.t(),
            job_queue_filter: String.t(),
            job_worker_filter: String.t(),
            config: config(),
            summary: summary(),
            queue_table: Table.t(),
            jobs_table: Table.t(),
            rss_table: Table.t(),
            bot_schedule_table: Table.t(),
            bot_event_log_table: Table.t(),
            maintenance_table: Table.t(),
            scraped_page_table: Table.t(),
            scraper_provenance_table: Table.t(),
            scraper_failure_table: Table.t(),
            persistence_table: Table.t()
          }

    @enforce_keys [
      :taken_at,
      :status,
      :status_reasons,
      :job_filter,
      :job_queue_filter,
      :job_worker_filter,
      :config,
      :summary,
      :queue_table,
      :jobs_table,
      :rss_table,
      :bot_schedule_table,
      :bot_event_log_table,
      :maintenance_table,
      :scraped_page_table,
      :scraper_provenance_table,
      :scraper_failure_table,
      :persistence_table
    ]
    defstruct [
      :taken_at,
      :status,
      :status_reasons,
      :job_filter,
      :job_queue_filter,
      :job_worker_filter,
      :config,
      :summary,
      :queue_table,
      :jobs_table,
      :rss_table,
      :bot_schedule_table,
      :bot_event_log_table,
      :maintenance_table,
      :scraped_page_table,
      :scraper_provenance_table,
      :scraper_failure_table,
      :persistence_table
    ]
  end

  @doc "The job filters the administrator can switch between in the Oban window."
  @spec job_filters() :: [%{id: String.t(), label: String.t(), states: [String.t()] | nil}]
  def job_filters, do: @job_filters

  @doc """
  Reads Oban configuration, queue state, recent jobs and durable job contracts.

  The snapshot is intentionally read-only. It never retries, cancels, resumes or
  starts a job; it only describes the health of the supervisor, queue table and
  the application's durable RSS scheduling contract.
  """
  @spec snapshot(keyword()) :: Snapshot.t()
  def snapshot(opts \\ []) do
    do_snapshot(opts)
  rescue
    _error -> failed_snapshot(opts)
  end

  defp do_snapshot(opts) do
    repo = Keyword.get(opts, :repo, Repo)
    name = Keyword.get(opts, :name, Oban)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    filter = normalize_filter(Keyword.get(opts, :filter, @default_filter))
    queue_filter = normalize_text_filter(Keyword.get(opts, :queue))
    worker_filter = normalize_text_filter(Keyword.get(opts, :worker))
    limit = Keyword.get(opts, :limit, @recent_limit)

    config = safe_config(name)
    running? = oban_running?(name)
    config_summary = summarize_config(config, repo, name)
    queue_stats = queue_stats(repo)
    global_stats = global_stats(repo)
    rss_rows = rss_rows(repo, now)
    bot_schedule_rows = bot_schedule_rows(repo, now)
    bot_event_log_rows = bot_event_log_rows(repo, now)
    maintenance_rows = maintenance_rows(repo, now)
    scraped_page_rows = scraped_page_rows(repo, now)
    persistence_rows = persistence_rows(repo)

    summary =
      summary(%{
        config: config_summary,
        queue_stats: queue_stats,
        global_stats: global_stats,
        rss_rows: rss_rows,
        bot_schedule_rows: bot_schedule_rows,
        bot_event_log_rows: bot_event_log_rows,
        maintenance_rows: maintenance_rows,
        scraped_page_rows: scraped_page_rows,
        persistence_rows: persistence_rows,
        running?: running?,
        now: now
      })

    {status, reasons} = health_status(summary, running?)

    %Snapshot{
      taken_at: now,
      status: status,
      status_reasons: reasons,
      job_filter: filter,
      job_queue_filter: queue_filter,
      job_worker_filter: worker_filter,
      config: config_summary,
      summary: summary,
      queue_table: queue_table(config_summary, queue_stats, now),
      jobs_table: jobs_table(repo, filter, limit, now, queue_filter, worker_filter),
      rss_table: rss_table(rss_rows),
      bot_schedule_table: bot_schedule_table(bot_schedule_rows),
      bot_event_log_table: bot_event_log_table(bot_event_log_rows),
      maintenance_table: maintenance_table(maintenance_rows),
      scraped_page_table: scraped_page_table(scraped_page_rows),
      scraper_provenance_table: scraper_provenance_table(repo),
      scraper_failure_table: scraper_failure_table(repo),
      persistence_table: persistence_table(persistence_rows)
    }
  end

  defp failed_snapshot(opts) do
    name = Keyword.get(opts, :name, Oban)
    repo = Keyword.get(opts, :repo, Repo)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    config_summary = summarize_config(:error, repo, name)

    %Snapshot{
      taken_at: now,
      status: :critical,
      status_reasons: ["Oban health could not read the database"],
      job_filter: normalize_filter(Keyword.get(opts, :filter, @default_filter)),
      job_queue_filter: normalize_text_filter(Keyword.get(opts, :queue)),
      job_worker_filter: normalize_text_filter(Keyword.get(opts, :worker)),
      config: config_summary,
      summary: empty_summary(false),
      queue_table: queue_table(config_summary, [], now),
      jobs_table: empty_jobs_table(),
      rss_table: rss_table([]),
      bot_schedule_table: bot_schedule_table([]),
      bot_event_log_table: bot_event_log_table([]),
      maintenance_table: maintenance_table([]),
      scraped_page_table: scraped_page_table([]),
      scraper_provenance_table: scraper_provenance_table(nil),
      scraper_failure_table: scraper_failure_table(nil),
      persistence_table: persistence_table([])
    }
  end

  defp queue_stats(repo) do
    Oban.Job
    |> group_by([job], [job.queue, job.state])
    |> select([job], %{
      queue: job.queue,
      state: job.state,
      count: count(job.id),
      oldest_scheduled_at: min(job.scheduled_at),
      oldest_attempted_at: min(job.attempted_at)
    })
    |> repo.all()
  end

  defp global_stats(repo) do
    repo.one(
      from job in Oban.Job,
        select: %{
          total_jobs: count(job.id),
          last_completed_at: max(job.completed_at),
          last_discarded_at: max(job.discarded_at)
        }
    )
  end

  defp summary(%{
         config: config,
         queue_stats: queue_stats,
         global_stats: global_stats,
         rss_rows: rss_rows,
         bot_schedule_rows: bot_schedule_rows,
         bot_event_log_rows: bot_event_log_rows,
         maintenance_rows: maintenance_rows,
         scraped_page_rows: scraped_page_rows,
         persistence_rows: persistence_rows,
         running?: running?,
         now: now
       }) do
    state_counts = state_counts(queue_stats)
    scraped_page_summary = scraped_page_summary(scraped_page_rows)
    persistence_summary = persistence_summary(persistence_rows)
    bot_event_log_summary = bot_event_log_summary(bot_event_log_rows)

    %{
      running?: running?,
      configured_queues: length(config.queues),
      queue_concurrency: config.queues |> Enum.map(&(&1.limit || 0)) |> Enum.sum(),
      total_jobs: Map.get(global_stats || %{}, :total_jobs, 0),
      active_jobs: sum_states(state_counts, @active_states),
      executing_jobs: Map.get(state_counts, "executing", 0),
      retryable_jobs: Map.get(state_counts, "retryable", 0),
      discarded_jobs: Map.get(state_counts, "discarded", 0),
      cancelled_jobs: Map.get(state_counts, "cancelled", 0),
      rss_feeds: length(rss_rows),
      rss_missing_jobs: Enum.count(rss_rows, &(&1.status == "missing job")),
      rss_feed_errors: Enum.count(rss_rows, &(&1.status == "feed error")),
      bot_schedules: length(bot_schedule_rows),
      bot_schedule_missing_jobs: Enum.count(bot_schedule_rows, &(&1.status == "missing job")),
      bot_schedule_failures: Enum.count(bot_schedule_rows, &(&1.status == "failed job")),
      bot_event_log_jobs: bot_event_log_summary.total,
      bot_event_log_active: bot_event_log_summary.active,
      bot_event_log_failures: bot_event_log_summary.failures,
      maintenance_sweeps: length(maintenance_rows),
      maintenance_failures: Enum.count(maintenance_rows, &(&1.failure_jobs > 0)),
      maintenance_pending_work: maintenance_rows |> Enum.map(& &1.pending_work) |> Enum.sum(),
      scraped_pages: scraped_page_summary.total,
      scraped_page_pending: scraped_page_summary.pending,
      scraped_page_retrying: scraped_page_summary.retrying,
      scraped_page_final_failures: scraped_page_summary.final_failures,
      scraped_page_failed: scraped_page_summary.failed,
      scraped_page_expired: scraped_page_summary.expired,
      persistence_requests: persistence_summary.total,
      persistence_pending: persistence_summary.pending,
      persistence_failed: persistence_summary.failed,
      persistence_payload_bytes: persistence_summary.payload_size_bytes,
      max_available_lag_ms: max_age(queue_stats, "available", now),
      max_executing_age_ms: max_age(queue_stats, "executing", now),
      last_completed_at: Map.get(global_stats || %{}, :last_completed_at),
      last_discarded_at: Map.get(global_stats || %{}, :last_discarded_at)
    }
  end

  defp empty_summary(running?) do
    %{
      running?: running?,
      configured_queues: 0,
      queue_concurrency: 0,
      total_jobs: 0,
      active_jobs: 0,
      executing_jobs: 0,
      retryable_jobs: 0,
      discarded_jobs: 0,
      cancelled_jobs: 0,
      rss_feeds: 0,
      rss_missing_jobs: 0,
      rss_feed_errors: 0,
      bot_schedules: 0,
      bot_schedule_missing_jobs: 0,
      bot_schedule_failures: 0,
      bot_event_log_jobs: 0,
      bot_event_log_active: 0,
      bot_event_log_failures: 0,
      maintenance_sweeps: 0,
      maintenance_failures: 0,
      maintenance_pending_work: 0,
      scraped_pages: 0,
      scraped_page_pending: 0,
      scraped_page_retrying: 0,
      scraped_page_final_failures: 0,
      scraped_page_failed: 0,
      scraped_page_expired: 0,
      persistence_requests: 0,
      persistence_pending: 0,
      persistence_failed: 0,
      persistence_payload_bytes: 0,
      max_available_lag_ms: nil,
      max_executing_age_ms: nil,
      last_completed_at: nil,
      last_discarded_at: nil
    }
  end

  defp health_status(summary, running?) do
    critical =
      []
      |> maybe_reason(not running?, "Oban supervisor is not running")
      |> maybe_reason(
        above?(summary.max_available_lag_ms, @available_lag_critical_ms),
        "available jobs have waited more than five minutes"
      )
      |> maybe_reason(
        above?(summary.max_executing_age_ms, @executing_age_critical_ms),
        "executing jobs have run for more than ten minutes"
      )

    warning =
      []
      |> maybe_reason(
        above?(summary.max_available_lag_ms, @available_lag_warning_ms),
        "available jobs are waiting more than one minute"
      )
      |> maybe_reason(
        above?(summary.max_executing_age_ms, @executing_age_warning_ms),
        "executing jobs have run for more than five minutes"
      )
      |> maybe_reason(summary.retryable_jobs > 0, "jobs are waiting for retry")
      |> maybe_reason(summary.discarded_jobs > 0, "jobs have been discarded")
      |> maybe_reason(summary.rss_missing_jobs > 0, "RSS feeds are missing successor jobs")
      |> maybe_reason(summary.rss_feed_errors > 0, "RSS feeds reported poll errors")
      |> maybe_reason(
        summary.bot_schedule_missing_jobs > 0,
        "bot schedules are missing successor jobs"
      )
      |> maybe_reason(summary.bot_schedule_failures > 0, "bot schedule jobs have failed")
      |> maybe_reason(summary.bot_event_log_failures > 0, "bot event log jobs have failed")
      |> maybe_reason(summary.maintenance_failures > 0, "maintenance sweeps have failed jobs")
      |> maybe_reason(summary.scraped_page_retrying > 0, "link previews are waiting for retry")
      |> maybe_reason(summary.persistence_failed > 0, "preference saves have failed requests")

    cond do
      critical != [] -> {:critical, critical}
      warning != [] -> {:warning, warning}
      true -> {:healthy, ["Oban queues and durable job contracts look healthy"]}
    end
  end

  defp queue_table(config, stats, now) do
    configured_names = Enum.map(config.queues, & &1.name)
    observed_names = stats |> Enum.map(& &1.queue) |> Enum.uniq()
    queues = (configured_names ++ observed_names) |> Enum.uniq() |> Enum.sort()
    stats_by_key = Map.new(stats, &{{&1.queue, &1.state}, &1})
    config_by_queue = Map.new(config.queues, &{&1.name, &1})
    states = state_names()

    rows =
      queues
      |> Enum.flat_map(fn queue ->
        Enum.map(states, fn state ->
          stat = Map.get(stats_by_key, {queue, state})
          spec = Map.get(config_by_queue, queue, %{})

          %{
            id: "#{queue}:#{state}",
            queue: queue,
            state: state,
            count: count_value(stat),
            limit: Map.get(spec, :limit),
            oldest_wait_ms: waiting_age(stat, state, now)
          }
        end)
      end)

    %Table{
      columns: [
        Table.column(:queue, "Queue", sortable: true),
        Table.column(:state, "State", sortable: true),
        Table.column(:count, "Jobs", format: :number, sortable: true),
        Table.column(:limit, "Limit", format: :number, sortable: true),
        Table.column(:oldest_wait_ms, "Oldest", format: :duration_ms, sortable: true)
      ],
      rows: rows,
      total: length(rows)
    }
  end

  defp jobs_table(repo, filter, limit, now, queue_filter, worker_filter) do
    filter_states = filter_states(filter)

    query =
      Oban.Job
      |> maybe_states(filter_states)
      |> maybe_queue(queue_filter)
      |> maybe_worker(worker_filter)
      |> order_by(
        [job],
        desc:
          fragment(
            "COALESCE(?, ?, ?, ?, ?, ?)",
            job.completed_at,
            job.discarded_at,
            job.cancelled_at,
            job.attempted_at,
            job.scheduled_at,
            job.inserted_at
          ),
        desc: job.id
      )
      |> limit(^limit)

    rows =
      query
      |> repo.all()
      |> Enum.map(&job_row(&1, now))

    %Table{
      columns: job_columns(),
      rows: rows,
      total: length(rows)
    }
  end

  defp empty_jobs_table do
    %Table{columns: job_columns(), rows: [], total: 0}
  end

  defp job_columns do
    [
      Table.column(:id, "ID", format: :number, sortable: true),
      Table.column(:queue, "Queue", sortable: true),
      Table.column(:state, "State", sortable: true),
      Table.column(:worker, "Worker", sortable: true),
      Table.column(:attempts, "Attempts", sortable: true),
      Table.column(:age_ms, "Age", format: :duration_ms, sortable: true),
      Table.column(:scheduled_at, "Scheduled", sortable: true),
      Table.column(:attempted_at, "Attempted", sortable: true),
      Table.column(:error, "Last error")
    ]
  end

  defp job_row(%Oban.Job{} = job, now) do
    %{
      id: job.id,
      queue: job.queue,
      state: job.state,
      worker: short_module(job.worker),
      attempts: "#{job.attempt}/#{job.max_attempts}",
      age_ms: job_age(job, now),
      scheduled_at: job.scheduled_at,
      attempted_at: job.attempted_at,
      error: latest_error(job.errors)
    }
  end

  defp rss_rows(repo, now) do
    jobs_by_feed =
      repo
      |> incomplete_rss_jobs()
      |> Enum.group_by(&rss_job_key/1)
      |> Map.new(fn {key, jobs} -> {key, best_rss_job(jobs)} end)

    Queries.list_bots()
    |> Enum.flat_map(&bot_feed_rows(&1, jobs_by_feed, now))
  end

  defp incomplete_rss_jobs(repo) do
    repo.all(
      from job in Oban.Job,
        where: job.worker == ^Oban.Worker.to_string(RSSPollWorker),
        where: job.queue == "rss",
        where: job.state in ^@rss_incomplete_states
    )
  end

  defp bot_feed_rows(bot, jobs_by_feed, now) do
    rss_config = Map.get(bot.capabilities || %{}, "rss") || %{}
    rss_enabled? = Map.get(rss_config, "enabled", true) != false

    bot
    |> Feeds.list()
    |> Enum.map(fn feed ->
      job = Map.get(jobs_by_feed, {bot.id, feed["id"]})
      status = rss_status(bot.enabled, rss_enabled?, feed, job)

      %{
        id: "#{bot.id}:#{feed["id"]}",
        bot: bot.nickname,
        feed_id: feed["id"],
        channel: feed["channel"],
        status: status,
        job_state: job && job.state,
        job_age_ms: job && job_age(job, now),
        scheduled_at: job && job.scheduled_at,
        last_polled_at: feed["last_polled_at"],
        last_error: feed["last_error"]
      }
    end)
  end

  defp rss_table(rows) do
    %Table{
      columns: [
        Table.column(:bot, "Bot", sortable: true),
        Table.column(:feed_id, "Feed", sortable: true),
        Table.column(:channel, "Channel", sortable: true),
        Table.column(:status, "Status", sortable: true),
        Table.column(:job_state, "Job", sortable: true),
        Table.column(:job_age_ms, "Job age", format: :duration_ms, sortable: true),
        Table.column(:scheduled_at, "Scheduled", sortable: true),
        Table.column(:last_polled_at, "Last poll", sortable: true),
        Table.column(:last_error, "Last error")
      ],
      rows: Enum.map(rows, &format_rss_row/1),
      total: length(rows)
    }
  end

  defp bot_schedule_rows(repo, now) do
    jobs_by_schedule =
      repo
      |> bot_schedule_jobs()
      |> Enum.group_by(&bot_schedule_job_key/1)
      |> Map.new(fn {key, jobs} -> {key, best_bot_schedule_job(jobs)} end)

    Queries.list_bots()
    |> Enum.flat_map(&bot_schedule_rows_for_bot(&1, jobs_by_schedule, now))
  end

  defp bot_schedule_jobs(repo) do
    states = (@active_states ++ @failure_states) |> Enum.uniq()

    repo.all(
      from job in Oban.Job,
        where: job.worker == ^Oban.Worker.to_string(BotScheduledMessageWorker),
        where: job.queue == "bots",
        where: job.state in ^states
    )
  end

  defp bot_schedule_rows_for_bot(bot, jobs_by_schedule, now) do
    scheduler_config = Map.get(bot.capabilities || %{}, "scheduler") || %{}
    scheduler_enabled? = Map.get(scheduler_config, "enabled", true) != false

    scheduler_config
    |> Map.get("schedules", [])
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn schedule ->
      schedule_id = Map.get(schedule, "id")
      job = Map.get(jobs_by_schedule, {bot.id, schedule_id})
      status = bot_schedule_status(bot.enabled, scheduler_enabled?, schedule, job)

      %{
        id: "#{bot.id}:#{schedule_id || "missing"}",
        bot: bot.nickname,
        schedule_id: schedule_id,
        type: schedule_type(schedule),
        channel: Map.get(schedule, "channel"),
        status: status,
        job_state: job && job.state,
        job_age_ms: job && job_age(job, now),
        scheduled_at: job && job.scheduled_at,
        last_fired: Map.get(schedule, "last_fired"),
        next_delay_ms: Scheduler.calculate_next_delay(schedule, now),
        last_error: job && latest_error(job.errors)
      }
    end)
  end

  defp bot_schedule_table(rows) do
    %Table{
      columns: [
        Table.column(:bot, "Bot", sortable: true),
        Table.column(:schedule_id, "Schedule", sortable: true),
        Table.column(:type, "Type", sortable: true),
        Table.column(:channel, "Channel", sortable: true),
        Table.column(:status, "Status", sortable: true),
        Table.column(:job_state, "Job", sortable: true),
        Table.column(:job_age_ms, "Job age", format: :duration_ms, sortable: true),
        Table.column(:scheduled_at, "Scheduled", sortable: true),
        Table.column(:last_fired, "Last fired", sortable: true),
        Table.column(:next_delay_ms, "Next due", format: :duration_ms, sortable: true),
        Table.column(:last_error, "Last error")
      ],
      rows: rows,
      total: length(rows)
    }
  end

  defp bot_event_log_rows(repo, now) do
    states = (@active_states ++ @failure_states) |> Enum.uniq()

    jobs =
      repo.all(
        from job in Oban.Job,
          where: job.worker == ^Oban.Worker.to_string(BotEventLogWorker),
          where: job.queue == "bots",
          where: job.state in ^states
      )

    jobs
    |> Enum.group_by(& &1.state)
    |> Enum.map(fn {state, state_jobs} ->
      failed_job = latest_failed_job(state_jobs)

      %{
        id: "bot_event_log:#{state}",
        state: state,
        status: bot_event_log_status(state),
        count: length(state_jobs),
        oldest_age_ms: oldest_job_age(state_jobs, now),
        last_error: failed_job && latest_error(failed_job.errors)
      }
    end)
    |> Enum.sort_by(&bot_event_log_state_rank(&1.state))
  end

  defp bot_event_log_summary(rows) do
    %{
      total: rows |> Enum.map(& &1.count) |> Enum.sum(),
      active:
        rows
        |> Enum.filter(&(&1.state in @active_states))
        |> Enum.map(& &1.count)
        |> Enum.sum(),
      failures:
        rows
        |> Enum.filter(&(&1.state in @failure_states))
        |> Enum.map(& &1.count)
        |> Enum.sum()
    }
  end

  defp bot_event_log_table(rows) do
    %Table{
      columns: [
        Table.column(:state, "State", sortable: true),
        Table.column(:status, "Status", sortable: true),
        Table.column(:count, "Jobs", format: :number, sortable: true),
        Table.column(:oldest_age_ms, "Oldest", format: :duration_ms, sortable: true),
        Table.column(:last_error, "Last error")
      ],
      rows: rows,
      total: length(rows)
    }
  end

  defp maintenance_rows(repo, now) do
    jobs_by_worker = maintenance_jobs_by_worker(repo)

    Enum.map(@maintenance_sweeps, fn sweep ->
      worker = Oban.Worker.to_string(sweep.worker)
      jobs = Map.get(jobs_by_worker, worker, [])
      active_jobs = Enum.count(jobs, &(&1.state in @active_states))
      failure_jobs = Enum.count(jobs, &(&1.state in @failure_states))
      last_completed_at = latest_timestamp(jobs, :completed_at)
      failed_job = latest_failed_job(jobs)
      pending_work = maintenance_pending_work(sweep.id, now)

      %{
        id: sweep.id,
        sweep: sweep.label,
        queue: sweep.queue,
        worker: short_module(worker),
        status: maintenance_status(active_jobs, failure_jobs, pending_work, last_completed_at),
        active_jobs: active_jobs,
        failure_jobs: failure_jobs,
        pending_work: pending_work,
        last_completed_at: last_completed_at,
        last_error: failed_job && latest_error(failed_job.errors)
      }
    end)
  end

  defp maintenance_jobs_by_worker(repo) do
    workers = Enum.map(@maintenance_sweeps, &Oban.Worker.to_string(&1.worker))

    Oban.Job
    |> where([job], job.worker in ^workers)
    |> repo.all()
    |> Enum.group_by(& &1.worker)
  end

  defp maintenance_pending_work("server_ban_expiry", now), do: ServerBans.expired_count(now)

  defp maintenance_pending_work("registered_channel_expiry", now),
    do: ChanExpiry.expired_count(now: now)

  defp maintenance_pending_work("registered_nick_expiry", now),
    do: NickExpiry.expired_count(now: now)

  defp maintenance_pending_work("attachment_orphan_cleanup", now),
    do: Attachments.orphan_upload_count(cutoff: DateTime.add(now, -3_600, :second))

  defp maintenance_pending_work("trusted_device_expiry", now),
    do: TrustedDevices.expired_device_count(now: now)

  defp maintenance_pending_work("chat_device_session_cleanup", now),
    do: TrustedDevices.stale_session_count(cutoff: DateTime.add(now, -300, :second))

  defp maintenance_pending_work("runtime_stale_cleanup", now) do
    counts =
      RuntimeStaleCleanup.counts(
        cutoff: DateTime.add(now, -RuntimeStaleCleanup.default_stale_after_seconds(), :second)
      )

    counts.total
  end

  defp maintenance_pending_work("channel_mute_expiry", now),
    do: ChannelMutes.expired_count(now: now)

  defp maintenance_pending_work("global_mute_expiry", now),
    do: GlobalMutes.expired_count(now: now)

  defp maintenance_pending_work("ignore_expired_cleanup", now),
    do: IgnoreList.expired_entry_count(now: now)

  defp maintenance_pending_work(_id, _now), do: 0

  defp maintenance_status(_active_jobs, failure_jobs, _pending_work, _last_completed_at)
       when failure_jobs > 0,
       do: "failed"

  defp maintenance_status(active_jobs, _failure_jobs, _pending_work, _last_completed_at)
       when active_jobs > 0,
       do: "active"

  defp maintenance_status(_active_jobs, _failure_jobs, pending_work, _last_completed_at)
       when pending_work > 0,
       do: "pending work"

  defp maintenance_status(_active_jobs, _failure_jobs, _pending_work, %DateTime{}), do: "ok"
  defp maintenance_status(_active_jobs, _failure_jobs, _pending_work, nil), do: "never run"

  defp maintenance_table(rows) do
    %Table{
      columns: [
        Table.column(:sweep, "Sweep", sortable: true),
        Table.column(:status, "Status", sortable: true),
        Table.column(:queue, "Queue", sortable: true),
        Table.column(:worker, "Worker", sortable: true),
        Table.column(:active_jobs, "Active", format: :number, sortable: true),
        Table.column(:failure_jobs, "Failures", format: :number, sortable: true),
        Table.column(:pending_work, "Pending work", format: :number, sortable: true),
        Table.column(:last_completed_at, "Last success", sortable: true),
        Table.column(:last_error, "Last error")
      ],
      rows: rows,
      total: length(rows)
    }
  end

  defp scraped_page_rows(repo, now) do
    ScraperStore.stats(repo: repo, now: now)
    |> ensure_scraped_page_statuses()
  end

  defp scraped_page_summary(rows) do
    %{
      total: rows |> Enum.map(& &1.count) |> Enum.sum(),
      pending: rows |> count_scraped_page_status("pending"),
      retrying: rows |> Enum.map(&(&1.retrying || 0)) |> Enum.sum(),
      final_failures: rows |> Enum.map(&(&1.final_failures || 0)) |> Enum.sum(),
      failed: rows |> count_scraped_page_status("failed"),
      expired: rows |> Enum.map(& &1.expired) |> Enum.sum()
    }
  end

  defp scraped_page_table(rows) do
    %Table{
      columns: [
        Table.column(:status, "Status", sortable: true),
        Table.column(:count, "Rows", format: :number, sortable: true),
        Table.column(:retrying, "Retrying", format: :number, sortable: true),
        Table.column(:final_failures, "Final failures", format: :number, sortable: true),
        Table.column(:expired, "Expired", format: :number, sortable: true),
        Table.column(:oldest_attempted_at, "Oldest attempt", sortable: true),
        Table.column(:newest_fetched_at, "Newest fetch", sortable: true)
      ],
      rows: rows,
      total: length(rows)
    }
  end

  # Where the archive is getting each field from. A wrong title is traceable to
  # the standard that supplied it without opening the row, and a shift towards
  # `html` says publishers' preview tags are being missed.
  defp scraper_provenance_table(nil), do: provenance_table_shell([])

  defp scraper_provenance_table(repo) do
    provenance_table_shell(ScraperStore.provenance_stats(repo: repo))
  end

  defp provenance_table_shell(rows) do
    %Table{
      columns: [
        Table.column(:field, "Field", sortable: true),
        Table.column(:total, "Pages", format: :number, sortable: true),
        Table.column(:top_source, "Mostly from", sortable: true),
        Table.column(:breakdown, "Breakdown")
      ],
      rows: rows,
      total: length(rows)
    }
  end

  # What stopped the pages that failed. The status counts say how many; this says
  # whether a site is down or simply will not answer a robot.
  defp scraper_failure_table(nil), do: failure_table_shell([])

  defp scraper_failure_table(repo),
    do: failure_table_shell(ScraperStore.failure_stats(repo: repo))

  defp failure_table_shell(rows) do
    %Table{
      columns: [
        Table.column(:reason, "Reason", sortable: true),
        Table.column(:count, "Pages", format: :number, sortable: true),
        Table.column(:newest_attempt, "Last tried", sortable: true),
        Table.column(:soonest_retry, "Next retry", sortable: true)
      ],
      rows: rows,
      total: length(rows)
    }
  end

  defp persistence_rows(repo) do
    repo
    |> then(&PreferencePersistence.stats(repo: &1))
    |> Enum.map(fn row ->
      Map.put(row, :id, "#{row.preference_type}:#{row.status}")
    end)
  end

  defp persistence_summary(rows) do
    %{
      total: rows |> Enum.map(& &1.count) |> Enum.sum(),
      pending:
        rows
        |> Enum.filter(&(&1.status in ["pending", "processing"]))
        |> Enum.map(& &1.count)
        |> Enum.sum(),
      failed: rows |> count_status("failed"),
      payload_size_bytes: rows |> Enum.map(&(&1.payload_size_bytes || 0)) |> Enum.sum()
    }
  end

  defp persistence_table(rows) do
    %Table{
      columns: [
        Table.column(:preference_type, "Type", sortable: true),
        Table.column(:status, "Status", sortable: true),
        Table.column(:count, "Rows", format: :number, sortable: true),
        Table.column(:payload_size_bytes, "Payload", format: :bytes, sortable: true),
        Table.column(:oldest_pending_at, "Oldest pending", sortable: true),
        Table.column(:last_attempted_at, "Last attempt", sortable: true)
      ],
      rows: rows,
      total: length(rows)
    }
  end

  defp format_rss_row(row) do
    %{row | last_error: format_error(row.last_error)}
  end

  defp state_counts(stats) do
    empty = Map.new(state_names(), &{&1, 0})

    Enum.reduce(stats, empty, fn stat, acc ->
      Map.update(acc, stat.state, stat.count, &(&1 + stat.count))
    end)
  end

  defp sum_states(counts, states) do
    states
    |> Enum.map(&Map.get(counts, &1, 0))
    |> Enum.sum()
  end

  defp max_age(stats, state, now) do
    stats
    |> Enum.filter(&(&1.state == state and &1.count > 0))
    |> Enum.map(&waiting_age(&1, state, now))
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
  end

  defp waiting_age(nil, _state, _now), do: nil

  defp waiting_age(%{state: "executing"} = stat, _state, now),
    do: age_ms(stat.oldest_attempted_at, now)

  defp waiting_age(%{oldest_scheduled_at: scheduled_at}, _state, now),
    do: age_ms(scheduled_at, now)

  defp job_age(%Oban.Job{state: "executing", attempted_at: attempted_at}, now) do
    age_ms(attempted_at, now)
  end

  defp job_age(%Oban.Job{state: state, scheduled_at: scheduled_at}, now)
       when state in ["available", "scheduled", "retryable", "suspended"] do
    age_ms(scheduled_at, now)
  end

  defp job_age(%Oban.Job{completed_at: %DateTime{} = completed_at}, now),
    do: age_ms(completed_at, now)

  defp job_age(%Oban.Job{discarded_at: %DateTime{} = discarded_at}, now),
    do: age_ms(discarded_at, now)

  defp job_age(%Oban.Job{cancelled_at: %DateTime{} = cancelled_at}, now),
    do: age_ms(cancelled_at, now)

  defp job_age(%Oban.Job{inserted_at: inserted_at}, now), do: age_ms(inserted_at, now)

  defp oldest_job_age(jobs, now) do
    jobs
    |> Enum.map(&job_age(&1, now))
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
  end

  defp age_ms(nil, _now), do: nil

  defp age_ms(timestamp, now) do
    max(DateTime.diff(now, timestamp, :millisecond), 0)
  end

  defp safe_config(name) do
    {:ok, Oban.config(name)}
  rescue
    _error -> :error
  catch
    :exit, _reason -> :error
  end

  defp summarize_config({:ok, config}, _repo, _name) do
    %{
      name: inspect(config.name),
      node: to_string(config.node),
      repo: inspect(config.repo),
      engine: inspect(config.engine),
      notifier: inspect_config_pair(config.notifier),
      peer: inspect_config_pair(config.peer),
      prefix: config.prefix,
      testing: to_string(config.testing),
      plugins: Enum.map(config.plugins, &inspect_config_pair/1),
      queues: queue_specs(config.queues)
    }
  end

  defp summarize_config(:error, repo, name) do
    %{
      name: inspect(name),
      node: nil,
      repo: inspect(repo),
      engine: nil,
      notifier: nil,
      peer: nil,
      prefix: nil,
      testing: nil,
      plugins: [],
      queues: []
    }
  end

  defp inspect_config_pair({module, _opts}), do: inspect(module)
  defp inspect_config_pair(module), do: inspect(module)

  defp queue_specs(queues) when is_list(queues) do
    Enum.map(queues, fn
      {name, opts} ->
        %{name: to_string(name), limit: queue_limit(opts)}

      name when is_atom(name) or is_binary(name) ->
        %{name: to_string(name), limit: nil}
    end)
  end

  defp queue_limit(opts) when is_list(opts), do: Keyword.get(opts, :limit)
  defp queue_limit(limit) when is_integer(limit), do: limit
  defp queue_limit(_opts), do: nil

  defp oban_running?(name) do
    case Oban.whereis(name) do
      pid when is_pid(pid) -> Process.alive?(pid)
      _other -> false
    end
  rescue
    _error -> false
  catch
    :exit, _reason -> false
  end

  defp normalize_filter(filter) do
    filter = to_string(filter)

    if Enum.any?(@job_filters, &(&1.id == filter)) do
      filter
    else
      @default_filter
    end
  end

  defp filter_states(filter) do
    @job_filters
    |> Enum.find(&(&1.id == filter))
    |> Map.get(:states)
  end

  defp maybe_states(query, nil), do: query
  defp maybe_states(query, states), do: where(query, [job], job.state in ^states)

  defp maybe_queue(query, ""), do: query
  defp maybe_queue(query, queue), do: where(query, [job], job.queue == ^queue)

  defp maybe_worker(query, ""), do: query

  defp maybe_worker(query, worker) do
    pattern = "%#{worker}%"
    where(query, [job], ilike(job.worker, ^pattern))
  end

  defp normalize_text_filter(nil), do: ""

  defp normalize_text_filter(filter) do
    filter
    |> to_string()
    |> String.trim()
  end

  defp state_names, do: Enum.map(Oban.Job.states(), &Atom.to_string/1)

  defp count_value(nil), do: 0
  defp count_value(%{count: count}), do: count

  defp rss_status(false, _rss_enabled?, _feed, _job), do: "bot disabled"
  defp rss_status(_bot_enabled?, false, _feed, _job), do: "rss disabled"

  defp rss_status(_bot_enabled?, _rss_enabled?, %{"last_error" => error}, _job)
       when not is_nil(error), do: "feed error"

  defp rss_status(_bot_enabled?, _rss_enabled?, _feed, %Oban.Job{state: state}), do: state
  defp rss_status(_bot_enabled?, _rss_enabled?, _feed, nil), do: "missing job"

  defp bot_schedule_status(false, _scheduler_enabled?, _schedule, _job), do: "bot disabled"

  defp bot_schedule_status(_bot_enabled?, false, _schedule, _job),
    do: "scheduler disabled"

  defp bot_schedule_status(_bot_enabled?, _scheduler_enabled?, %{"id" => id}, %Oban.Job{
         state: state
       })
       when is_binary(id) and id != "" and state in ["discarded", "cancelled"],
       do: "failed job"

  defp bot_schedule_status(_bot_enabled?, _scheduler_enabled?, %{"id" => id}, %Oban.Job{
         state: state
       })
       when is_binary(id) and id != "",
       do: state

  defp bot_schedule_status(_bot_enabled?, _scheduler_enabled?, %{"id" => id}, nil)
       when is_binary(id) and id != "",
       do: "missing job"

  defp bot_schedule_status(_bot_enabled?, _scheduler_enabled?, _schedule, _job),
    do: "invalid schedule"

  defp rss_job_key(%Oban.Job{args: args}) do
    {Map.get(args, "bot_id") || Map.get(args, :bot_id),
     Map.get(args, "feed_id") || Map.get(args, :feed_id)}
  end

  defp bot_schedule_job_key(%Oban.Job{args: args}) do
    {Map.get(args, "bot_id") || Map.get(args, :bot_id),
     Map.get(args, "schedule_id") || Map.get(args, :schedule_id)}
  end

  defp best_rss_job(jobs) do
    Enum.min_by(jobs, &rss_job_rank/1)
  end

  defp best_bot_schedule_job(jobs) do
    Enum.min_by(jobs, &rss_job_rank/1)
  end

  defp rss_job_rank(%Oban.Job{} = job) do
    {rss_state_rank(job.state),
     rank_time(job.scheduled_at || job.attempted_at || job.inserted_at), job.id}
  end

  defp schedule_type(%{"type" => "interval", "interval_min" => minutes}),
    do: "interval/#{minutes}m"

  defp schedule_type(%{"type" => "daily", "time" => time}), do: "daily@#{time}"
  defp schedule_type(_schedule), do: "unknown"

  defp bot_event_log_status(state) when state in @failure_states, do: "failed"
  defp bot_event_log_status(state) when state in @active_states, do: "active"
  defp bot_event_log_status(_state), do: "retained"

  defp bot_event_log_state_rank("executing"), do: 0
  defp bot_event_log_state_rank("available"), do: 1
  defp bot_event_log_state_rank("retryable"), do: 2
  defp bot_event_log_state_rank("scheduled"), do: 3
  defp bot_event_log_state_rank("suspended"), do: 4
  defp bot_event_log_state_rank("discarded"), do: 5
  defp bot_event_log_state_rank("cancelled"), do: 6
  defp bot_event_log_state_rank(_state), do: 7

  defp ensure_scraped_page_statuses(rows) do
    rows_by_status = Map.new(rows, &{&1.status, &1})

    Enum.map(~w(pending ready failed), fn status ->
      rows_by_status
      |> Map.get(status, %{
        status: status,
        count: 0,
        retrying: 0,
        final_failures: 0,
        expired: 0,
        oldest_attempted_at: nil,
        newest_fetched_at: nil
      })
      |> Map.put(:id, "scraped_page:#{status}")
    end)
  end

  defp count_scraped_page_status(rows, status) do
    rows
    |> Enum.find(%{count: 0}, &(&1.status == status))
    |> Map.get(:count)
  end

  defp count_status(rows, status) do
    rows
    |> Enum.filter(&(&1.status == status))
    |> Enum.map(& &1.count)
    |> Enum.sum()
  end

  defp rss_state_rank("executing"), do: 0
  defp rss_state_rank("available"), do: 1
  defp rss_state_rank("retryable"), do: 2
  defp rss_state_rank("scheduled"), do: 3
  defp rss_state_rank("suspended"), do: 4
  defp rss_state_rank(_state), do: 5

  defp latest_error(nil), do: nil
  defp latest_error([]), do: nil

  defp latest_error([error | _rest]) do
    error
    |> error_value()
    |> format_error()
  end

  defp error_value(error) when is_map(error) do
    Map.get(error, "error") || Map.get(error, :error) || Map.get(error, "message") ||
      Map.get(error, :message) || error
  end

  defp error_value(error), do: error

  defp format_error(nil), do: nil
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp short_module(worker) when is_binary(worker) do
    worker
    |> String.trim_leading("Elixir.")
    |> String.split(".")
    |> List.last()
  end

  defp short_module(worker), do: inspect(worker)

  defp rank_time(nil), do: 0
  defp rank_time(%DateTime{} = timestamp), do: DateTime.to_unix(timestamp, :microsecond)

  defp latest_timestamp(jobs, field) do
    jobs
    |> Enum.map(&Map.get(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.max_by(&rank_time/1, fn -> nil end)
  end

  defp latest_failed_job(jobs) do
    jobs
    |> Enum.filter(&(&1.state in @failure_states))
    |> Enum.max_by(
      &rank_time(&1.discarded_at || &1.cancelled_at || &1.attempted_at || &1.inserted_at),
      fn -> nil end
    )
  end

  defp above?(nil, _threshold), do: false
  defp above?(value, threshold), do: value > threshold

  defp maybe_reason(reasons, true, reason), do: [reason | reasons]
  defp maybe_reason(reasons, false, _reason), do: reasons
end
