defmodule RetroHexChat.Jobs do
  @moduledoc """
  Application boundary for durable background jobs.

  Domain code should enqueue work through this module instead of reaching into
  Oban directly. That keeps queue ownership, cancellation, and future job
  conventions in one place as more platform work moves out of request/process
  lifecycles.
  """

  import Ecto.Query

  alias Oban.Job
  alias RetroHexChat.Repo

  require Logger

  @cancellable_states ~w(available scheduled executing retryable suspended)

  # A successor is asked for while its predecessor is still `executing`, so
  # that state must not count as the duplicate the uniqueness check avoids.
  @follow_up_unique_states [:available, :scheduled, :retryable, :suspended]

  @type insert_result :: {:ok, Job.t()} | {:error, Ecto.Changeset.t()}

  @doc "Insert a prepared Oban job changeset."
  @spec insert(Ecto.Changeset.t()) :: insert_result()
  def insert(changeset), do: Oban.insert(changeset)

  @doc """
  Enqueues `worker` with `args` to run after `delay_ms` (at least a second),
  and logs the outcome as `event` with each argument as a `key=value` pair.

  Pass `follow_up: true` when a running job asks for its own successor.
  """
  @spec schedule_in(module(), keyword(), non_neg_integer(), String.t(), keyword()) ::
          :ok | {:error, Ecto.Changeset.t()}
  def schedule_in(worker, args, delay_ms, event, opts \\ []) do
    delay_s = delay_ms |> div(1_000) |> max(1)
    fields = Enum.map_join(args, " ", fn {key, value} -> "#{key}=#{value}" end)

    job_opts =
      if Keyword.get(opts, :follow_up, false),
        do: [schedule_in: delay_s, unique: [states: @follow_up_unique_states]],
        else: [schedule_in: delay_s]

    args
    |> Map.new()
    |> worker.new(job_opts)
    |> insert()
    |> case do
      {:ok, job} ->
        Logger.info(
          "#{event} #{fields} queue=#{job.queue} state=#{job.state} " <>
            "conflict=#{job.conflict?} delay_s=#{delay_s}"
        )

        :ok

      {:error, changeset} ->
        Logger.warning("#{event}_error #{fields} reason=changeset_error")
        {:error, changeset}
    end
  end

  @doc "Count all Oban jobs. Used by administrative full-reset previews."
  @spec count_all() :: non_neg_integer()
  def count_all, do: Repo.aggregate(Job, :count)

  @doc "Delete all Oban jobs. Used only by the administrative full-reset flow."
  @spec delete_all() :: {non_neg_integer(), nil | [term()]}
  def delete_all, do: Repo.delete_all(Job)

  @doc """
  A bot's job addressed by the bot's id, the key of what it runs (a feed, a
  schedule) and a delay that is not in the past.
  """
  defguard schedulable(bot_id, key, delay_ms)
           when is_integer(bot_id) and is_binary(key) and is_integer(delay_ms) and delay_ms >= 0

  @doc "Cancel incomplete jobs for a worker, queue, and JSON args subset."
  @spec cancel_worker_jobs(module(), atom() | String.t(), map()) :: :ok
  def cancel_worker_jobs(worker, queue, args) when is_map(args) do
    worker = Oban.Worker.to_string(worker)
    queue = to_string(queue)

    {:ok, _count} =
      Job
      |> where([job], job.worker == ^worker)
      |> where([job], job.queue == ^queue)
      |> where([job], job.state in ^@cancellable_states)
      |> where([job], fragment("? @> ?", job.args, type(^args, :map)))
      |> Oban.cancel_all_jobs()

    :ok
  end
end
