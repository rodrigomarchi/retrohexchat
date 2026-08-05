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

  @cancellable_states ~w(available scheduled executing retryable suspended)

  @type insert_result :: {:ok, Job.t()} | {:error, Ecto.Changeset.t()}

  @doc "Insert a prepared Oban job changeset."
  @spec insert(Ecto.Changeset.t()) :: insert_result()
  def insert(changeset), do: Oban.insert(changeset)

  @doc "Cancel incomplete jobs for a worker, queue, and JSON args subset."
  @spec cancel_worker_jobs(module(), atom() | String.t(), map()) :: {:ok, non_neg_integer()}
  def cancel_worker_jobs(worker, queue, args) when is_map(args) do
    worker = Oban.Worker.to_string(worker)
    queue = to_string(queue)

    Job
    |> where([job], job.worker == ^worker)
    |> where([job], job.queue == ^queue)
    |> where([job], job.state in ^@cancellable_states)
    |> where([job], fragment("? @> ?", job.args, type(^args, :map)))
    |> Oban.cancel_all_jobs()
  end
end
