defmodule RetroHexChat.Jobs.Retry do
  @moduledoc """
  How long a job may run, and how long it waits before trying again.

  Every worker in this directory answers Oban's `timeout/1` and `backoff/1` the
  same way, and only three numbers differ between them. Writing those two
  callbacks out per worker meant the policy was copied rather than read — three
  workers spelled the same fifteen-minute ceiling `900` while six others spelled
  it `15 * 60`, which is what a number looks like once nobody is comparing them.

  The wait grows with the square of the attempt and is capped, so a job that
  fails retries quickly at first and then stops crowding the queue. Both values
  are per worker because a scrape that failed on a slow page should come back
  sooner than an expiry sweep that failed on a locked row.

      use Oban.Worker, queue: :maintenance, max_attempts: 3

      use RetroHexChat.Jobs.Retry,
        timeout: :timer.seconds(30),
        cap_seconds: 15 * 60,
        step_seconds: 30
  """

  @doc """
  Defines Oban's `timeout/1` and `backoff/1` for the calling worker.

  Goes after `use Oban.Worker`, which is what declares the behaviour these two
  implement.
  """
  defmacro __using__(opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    cap_seconds = Keyword.fetch!(opts, :cap_seconds)
    step_seconds = Keyword.fetch!(opts, :step_seconds)

    quote do
      @impl Oban.Worker
      @spec timeout(Oban.Job.t()) :: pos_integer()
      def timeout(_job), do: unquote(timeout)

      @impl Oban.Worker
      @spec backoff(Oban.Job.t()) :: pos_integer()
      def backoff(%Oban.Job{attempt: attempt}) do
        unquote(__MODULE__).wait_seconds(
          attempt,
          unquote(cap_seconds),
          unquote(step_seconds)
        )
      end
    end
  end

  @doc "How many seconds to wait before the attempt after `attempt`."
  @spec wait_seconds(pos_integer(), pos_integer(), pos_integer()) :: pos_integer()
  def wait_seconds(attempt, cap_seconds, step_seconds)
      when is_integer(attempt) and attempt > 0 do
    min(cap_seconds, attempt * attempt * step_seconds)
  end
end
