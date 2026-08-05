defmodule RetroHexChat.Jobs.ObanHealth do
  @moduledoc """
  Read-only health snapshot for the Oban runtime.

  The application only schedules durable background work through Oban, so an
  administrator needs two views at once: generic queue health and the domain
  contract that every configured RSS feed has an incomplete successor job.
  This module owns both readings and returns them as `Admin.Table` values so
  the web surface never has to know Oban's schema.
  """

  import Ecto.Query

  alias RetroHexChat.Admin.Table
  alias RetroHexChat.Bots.{Feeds, Queries}
  alias RetroHexChat.Jobs.RSSPollWorker
  alias RetroHexChat.Repo

  @default_filter "active"
  @recent_limit 30
  @available_lag_warning_ms 60_000
  @available_lag_critical_ms 300_000
  @executing_age_warning_ms 300_000
  @executing_age_critical_ms 600_000

  @active_states ~w(available scheduled executing retryable suspended)
  @failure_states ~w(retryable discarded cancelled)
  @rss_incomplete_states ~w(available scheduled executing retryable suspended)

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
            config: config(),
            summary: summary(),
            queue_table: Table.t(),
            jobs_table: Table.t(),
            rss_table: Table.t()
          }

    @enforce_keys [
      :taken_at,
      :status,
      :status_reasons,
      :job_filter,
      :config,
      :summary,
      :queue_table,
      :jobs_table,
      :rss_table
    ]
    defstruct [
      :taken_at,
      :status,
      :status_reasons,
      :job_filter,
      :config,
      :summary,
      :queue_table,
      :jobs_table,
      :rss_table
    ]
  end

  @doc "The job filters the administrator can switch between in the Oban window."
  @spec job_filters() :: [%{id: String.t(), label: String.t(), states: [String.t()] | nil}]
  def job_filters, do: @job_filters

  @doc """
  Reads Oban configuration, queue state, recent jobs and RSS successor coverage.

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
    limit = Keyword.get(opts, :limit, @recent_limit)

    config = safe_config(name)
    running? = oban_running?(name)
    config_summary = summarize_config(config, repo, name)
    queue_stats = queue_stats(repo)
    global_stats = global_stats(repo)
    rss_rows = rss_rows(repo, now)
    summary = summary(config_summary, queue_stats, global_stats, rss_rows, running?, now)

    {status, reasons} = health_status(summary, running?)

    %Snapshot{
      taken_at: now,
      status: status,
      status_reasons: reasons,
      job_filter: filter,
      config: config_summary,
      summary: summary,
      queue_table: queue_table(config_summary, queue_stats, now),
      jobs_table: jobs_table(repo, filter, limit, now),
      rss_table: rss_table(rss_rows)
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
      config: config_summary,
      summary: empty_summary(false),
      queue_table: queue_table(config_summary, [], now),
      jobs_table: empty_jobs_table(),
      rss_table: rss_table([])
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

  defp summary(config, queue_stats, global_stats, rss_rows, running?, now) do
    state_counts = state_counts(queue_stats)

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

    cond do
      critical != [] -> {:critical, critical}
      warning != [] -> {:warning, warning}
      true -> {:healthy, ["Oban queues and RSS successor jobs look healthy"]}
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

  defp jobs_table(repo, filter, limit, now) do
    filter_states = filter_states(filter)

    query =
      Oban.Job
      |> maybe_states(filter_states)
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

  defp state_names, do: Enum.map(Oban.Job.states(), &Atom.to_string/1)

  defp count_value(nil), do: 0
  defp count_value(%{count: count}), do: count

  defp rss_status(false, _rss_enabled?, _feed, _job), do: "bot disabled"
  defp rss_status(_bot_enabled?, false, _feed, _job), do: "rss disabled"

  defp rss_status(_bot_enabled?, _rss_enabled?, %{"last_error" => error}, _job)
       when not is_nil(error), do: "feed error"

  defp rss_status(_bot_enabled?, _rss_enabled?, _feed, %Oban.Job{state: state}), do: state
  defp rss_status(_bot_enabled?, _rss_enabled?, _feed, nil), do: "missing job"

  defp rss_job_key(%Oban.Job{args: args}) do
    {Map.get(args, "bot_id") || Map.get(args, :bot_id),
     Map.get(args, "feed_id") || Map.get(args, :feed_id)}
  end

  defp best_rss_job(jobs) do
    Enum.min_by(jobs, &rss_job_rank/1)
  end

  defp rss_job_rank(%Oban.Job{} = job) do
    {rss_state_rank(job.state),
     rank_time(job.scheduled_at || job.attempted_at || job.inserted_at), job.id}
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

  defp above?(nil, _threshold), do: false
  defp above?(value, threshold), do: value > threshold

  defp maybe_reason(reasons, true, reason), do: [reason | reasons]
  defp maybe_reason(reasons, false, _reason), do: reasons
end
