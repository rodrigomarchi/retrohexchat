defmodule RetroHexChat.Jobs.BotScheduledMessageWorker do
  @moduledoc """
  Durable worker for bot scheduled messages.
  """

  use Oban.Worker,
    queue: :bots,
    max_attempts: 5,
    tags: ["bots", "scheduler"],
    unique: [
      fields: [:worker, :queue, :args],
      keys: [:bot_id, :schedule_id],
      states: :incomplete,
      period: :infinity
    ],
    replace: [
      available: [:scheduled_at],
      scheduled: [:scheduled_at]
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(1),
    cap_seconds: 30 * 60,
    step_seconds: 60

  import Ecto.Query

  alias RetroHexChat.Bots.Bot
  alias RetroHexChat.Bots.Capabilities.Scheduler
  alias RetroHexChat.Bots.Capabilities.Scheduler.Durable
  alias RetroHexChat.Bots.Output
  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Bots.Server
  alias RetroHexChat.Observability
  alias RetroHexChat.Repo

  require Logger

  @scheduler_capability "scheduler"

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:cancel, String.t()} | {:error, term()}
  def perform(%Oban.Job{args: %{"bot_id" => bot_id, "schedule_id" => schedule_id}}) do
    Observability.span(
      [:retro_hex_chat, :bots, :scheduler, :fire],
      %{bot_id: bot_id, schedule_id: schedule_id},
      fn -> do_perform(bot_id, schedule_id) end,
      &fire_result_metadata/1
    )
  end

  @spec do_perform(integer(), String.t()) :: :ok | {:cancel, String.t()} | {:error, term()}
  defp do_perform(bot_id, schedule_id) do
    Logger.info("bot_schedule_fire_start bot_id=#{bot_id} schedule_id=#{schedule_id}")

    with {:ok, fire} <- persist_fire(bot_id, schedule_id),
         :ok <- sync_running_bot(fire.bot),
         :ok <- deliver(fire),
         :ok <- Durable.schedule_follow_up(bot_id, schedule_id, fire.next_delay_ms) do
      Observability.set_current_span_attributes(fire_summary(fire))
      Logger.info(log_line("bot_schedule_fire_stop", fire))
      :ok
    else
      {:cancel, reason} ->
        Logger.info(
          "bot_schedule_fire_cancel bot_id=#{bot_id} schedule_id=#{schedule_id} reason=#{log_value(reason)}"
        )

        {:cancel, reason}

      {:error, reason} ->
        Logger.warning(
          "bot_schedule_fire_error bot_id=#{bot_id} schedule_id=#{schedule_id} reason=#{log_value(reason)}"
        )

        {:error, reason}
    end
  end

  @spec persist_fire(integer(), String.t()) ::
          {:ok, map()} | {:cancel, String.t()} | {:error, term()}
  defp persist_fire(bot_id, schedule_id) do
    now = DateTime.utc_now()

    case Repo.transaction(fn -> apply_under_lock(bot_id, schedule_id, now) end) do
      {:ok, {:ok, fire}} -> {:ok, fire}
      {:ok, {:cancel, reason}} -> {:cancel, reason}
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec apply_under_lock(integer(), String.t(), DateTime.t()) ::
          {:ok, map()} | {:cancel, String.t()} | {:error, term()}
  defp apply_under_lock(bot_id, schedule_id, now) do
    with %Bot{} = bot <- lock_bot(bot_id),
         true <- bot.enabled,
         {:ok, scheduler_config} <- enabled_scheduler_config(bot),
         {:ok, schedule} <- find_schedule(scheduler_config, schedule_id),
         {:ok, channel} <- schedule_channel(schedule),
         {:ok, message} <- schedule_message(schedule) do
      state = Scheduler.init_state(scheduler_config)
      schedules = Scheduler.mark_schedule_fired(state.schedules, schedule_id, now)
      updated_schedule = Scheduler.find_schedule(schedules, schedule_id) || schedule
      updated_scheduler = Map.merge(scheduler_config, %{"schedules" => schedules})
      capabilities = Map.put(bot.capabilities || %{}, @scheduler_capability, updated_scheduler)

      case Queries.update_bot(bot, %{capabilities: capabilities}) do
        {:ok, updated_bot} ->
          {:ok,
           %{
             bot: updated_bot,
             channel: channel,
             message: message,
             schedule: updated_schedule,
             schedule_id: schedule_id,
             next_delay_ms: Scheduler.calculate_next_delay(updated_schedule, now)
           }}

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      nil -> {:cancel, "bot not found"}
      false -> {:cancel, "bot disabled"}
      {:cancel, reason} -> {:cancel, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec lock_bot(integer()) :: Bot.t() | nil
  defp lock_bot(bot_id) do
    Bot
    |> where([bot], bot.id == ^bot_id)
    |> lock("FOR UPDATE")
    |> Repo.one()
  end

  @spec enabled_scheduler_config(Bot.t()) :: {:ok, map()} | {:cancel, String.t()}
  defp enabled_scheduler_config(%Bot{capabilities: capabilities}) do
    case Map.get(capabilities || %{}, @scheduler_capability) do
      %{"enabled" => false} -> {:cancel, "scheduler disabled"}
      config when is_map(config) -> {:ok, config}
      _other -> {:cancel, "scheduler not configured"}
    end
  end

  @spec find_schedule(map(), String.t()) :: {:ok, map()} | {:cancel, String.t()}
  defp find_schedule(scheduler_config, schedule_id) do
    scheduler_config
    |> Scheduler.init_state()
    |> Map.fetch!(:schedules)
    |> Scheduler.find_schedule(schedule_id)
    |> case do
      nil -> {:cancel, "schedule removed"}
      schedule -> {:ok, schedule}
    end
  end

  @spec schedule_channel(map()) :: {:ok, String.t()} | {:cancel, String.t()}
  defp schedule_channel(%{"channel" => channel}) when is_binary(channel) and channel != "" do
    {:ok, channel}
  end

  defp schedule_channel(_schedule), do: {:cancel, "schedule channel missing"}

  @spec schedule_message(map()) :: {:ok, String.t()} | {:cancel, String.t()}
  defp schedule_message(%{"message" => message}) when is_binary(message) and message != "" do
    {:ok, message}
  end

  defp schedule_message(_schedule), do: {:cancel, "schedule message missing"}

  @spec sync_running_bot(Bot.t()) :: :ok
  defp sync_running_bot(bot) do
    Server.sync_capabilities(bot.nickname, bot.capabilities)
  catch
    :exit, _reason -> :ok
  end

  @spec deliver(map()) :: :ok | {:error, term()}
  defp deliver(%{bot: bot, channel: channel, message: message}) do
    Output.send(channel, bot.nickname, %{delivery: :public, content: message})
  end

  @spec fire_summary(map()) :: map()
  defp fire_summary(fire) do
    %{
      bot: fire.bot.nickname,
      channel: fire.channel,
      schedule_id: fire.schedule_id,
      schedule_type: fire.schedule["type"],
      messages_sent: 1,
      next_delay_ms: fire.next_delay_ms
    }
  end

  defp fire_result_metadata(:ok), do: %{result: "ok"}
  defp fire_result_metadata({:cancel, reason}), do: %{result: "cancel", reason: reason}
  defp fire_result_metadata({:error, reason}), do: %{result: "error", reason: log_value(reason)}

  defp log_line(prefix, fire) do
    "#{prefix} bot_id=#{fire.bot.id} bot=#{fire.bot.nickname} schedule_id=#{fire.schedule_id} " <>
      "channel=#{fire.channel} next_delay_ms=#{fire.next_delay_ms}"
  end

  defp log_value(value) when is_binary(value), do: value
  defp log_value(value) when is_atom(value), do: Atom.to_string(value)
  defp log_value(%Ecto.Changeset{}), do: "changeset_error"
  defp log_value(value), do: inspect(value)
end
