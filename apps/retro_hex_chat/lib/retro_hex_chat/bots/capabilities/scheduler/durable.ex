defmodule RetroHexChat.Bots.Capabilities.Scheduler.Durable do
  @moduledoc """
  Scheduling boundary for bot scheduled messages.

  The scheduler capability owns parsing and durable state. This boundary owns how
  each configured schedule becomes background work.
  """

  @callback reconcile(integer(), [map()]) :: :ok | {:error, term()}
  @callback schedule(integer(), String.t(), non_neg_integer()) :: :ok | {:error, term()}
  @callback schedule_follow_up(integer(), String.t(), non_neg_integer()) :: :ok | {:error, term()}
  @callback cancel(integer(), String.t()) :: :ok | {:error, term()}
  @callback cancel_bot(integer()) :: :ok | {:error, term()}

  @doc "Cancel stale jobs for a bot and ensure one incomplete job per schedule."
  @spec reconcile(integer() | nil, [map()] | nil) :: :ok | {:error, term()}
  def reconcile(bot_id, schedules) when is_integer(bot_id) and is_list(schedules) do
    impl().reconcile(bot_id, schedules)
  end

  def reconcile(_bot_id, _schedules), do: {:error, :invalid_bot_schedules}

  @doc "Ensure a durable scheduled message job exists after `delay_ms`."
  @spec schedule(integer() | nil, String.t() | nil, non_neg_integer()) :: :ok | {:error, term()}
  def schedule(bot_id, schedule_id, delay_ms)
      when is_integer(bot_id) and is_binary(schedule_id) and is_integer(delay_ms) and
             delay_ms >= 0 do
    impl().schedule(bot_id, schedule_id, delay_ms)
  end

  def schedule(_bot_id, _schedule_id, _delay_ms), do: {:error, :invalid_bot_schedule}

  @doc "Ensure the next durable scheduled message job exists after a successful fire."
  @spec schedule_follow_up(integer() | nil, String.t() | nil, non_neg_integer()) ::
          :ok | {:error, term()}
  def schedule_follow_up(bot_id, schedule_id, delay_ms)
      when is_integer(bot_id) and is_binary(schedule_id) and is_integer(delay_ms) and
             delay_ms >= 0 do
    impl().schedule_follow_up(bot_id, schedule_id, delay_ms)
  end

  def schedule_follow_up(_bot_id, _schedule_id, _delay_ms), do: {:error, :invalid_bot_schedule}

  @doc "Cancel incomplete durable jobs for one schedule."
  @spec cancel(integer() | nil, String.t() | nil) :: :ok | {:error, term()}
  def cancel(bot_id, schedule_id) when is_integer(bot_id) and is_binary(schedule_id) do
    impl().cancel(bot_id, schedule_id)
  end

  def cancel(_bot_id, _schedule_id), do: :ok

  @doc "Cancel incomplete durable scheduled-message jobs for a bot."
  @spec cancel_bot(integer() | nil) :: :ok | {:error, term()}
  def cancel_bot(bot_id) when is_integer(bot_id), do: impl().cancel_bot(bot_id)
  def cancel_bot(_bot_id), do: :ok

  @doc false
  @spec impl() :: module()
  def impl do
    Application.get_env(
      :retro_hex_chat,
      :bot_schedule_scheduler,
      RetroHexChat.Bots.Capabilities.Scheduler.Durable.Oban
    )
  end
end

defmodule RetroHexChat.Bots.Capabilities.Scheduler.Durable.Oban do
  @moduledoc false

  alias RetroHexChat.Bots.Capabilities.Scheduler
  alias RetroHexChat.Jobs
  alias RetroHexChat.Jobs.BotScheduledMessageWorker

  require Logger

  @behaviour RetroHexChat.Bots.Capabilities.Scheduler.Durable

  @follow_up_unique_states [:available, :scheduled, :retryable, :suspended]

  @impl true
  @spec reconcile(integer(), [map()]) :: :ok | {:error, term()}
  def reconcile(bot_id, schedules) do
    with :ok <- cancel_bot(bot_id) do
      schedules
      |> Enum.filter(&valid_schedule?/1)
      |> Enum.reduce_while(:ok, &reconcile_schedule(bot_id, &1, &2))
    end
  end

  defp reconcile_schedule(bot_id, schedule, :ok) do
    delay_ms = Scheduler.calculate_next_delay(schedule)

    if delay_ms <= 0 do
      {:cont, :ok}
    else
      continue_schedule_result(schedule(bot_id, schedule["id"], delay_ms))
    end
  end

  defp continue_schedule_result(:ok), do: {:cont, :ok}
  defp continue_schedule_result({:error, reason}), do: {:halt, {:error, reason}}

  @impl true
  @spec schedule(integer(), String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def schedule(bot_id, schedule_id, delay_ms) do
    do_schedule(bot_id, schedule_id, delay_ms, [])
  end

  @impl true
  @spec schedule_follow_up(integer(), String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def schedule_follow_up(bot_id, schedule_id, delay_ms) do
    do_schedule(bot_id, schedule_id, delay_ms, unique: [states: @follow_up_unique_states])
  end

  @impl true
  @spec cancel(integer(), String.t()) :: :ok | {:error, term()}
  def cancel(bot_id, schedule_id) do
    {:ok, _count} =
      Jobs.cancel_worker_jobs(BotScheduledMessageWorker, :bots, %{
        "bot_id" => bot_id,
        "schedule_id" => schedule_id
      })

    :ok
  end

  @impl true
  @spec cancel_bot(integer()) :: :ok | {:error, term()}
  def cancel_bot(bot_id) do
    {:ok, _count} =
      Jobs.cancel_worker_jobs(BotScheduledMessageWorker, :bots, %{"bot_id" => bot_id})

    :ok
  end

  @spec do_schedule(integer(), String.t(), non_neg_integer(), keyword()) :: :ok | {:error, term()}
  defp do_schedule(bot_id, schedule_id, delay_ms, opts) do
    delay_s = delay_ms |> div(1_000) |> max(1)

    %{bot_id: bot_id, schedule_id: schedule_id}
    |> BotScheduledMessageWorker.new(Keyword.put(opts, :schedule_in, delay_s))
    |> Jobs.insert()
    |> case do
      {:ok, job} ->
        Logger.info(
          "bot_schedule_job_schedule bot_id=#{bot_id} schedule_id=#{schedule_id} " <>
            "queue=#{job.queue} state=#{job.state} conflict=#{job.conflict?} delay_s=#{delay_s}"
        )

        :ok

      {:error, changeset} ->
        Logger.warning(
          "bot_schedule_job_schedule_error bot_id=#{bot_id} schedule_id=#{schedule_id} reason=changeset_error"
        )

        {:error, changeset}
    end
  end

  defp valid_schedule?(%{"id" => id}) when is_binary(id) and id != "", do: true
  defp valid_schedule?(_schedule), do: false
end
