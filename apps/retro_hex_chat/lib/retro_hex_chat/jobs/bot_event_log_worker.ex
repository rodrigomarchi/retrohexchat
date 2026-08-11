defmodule RetroHexChat.Jobs.BotEventLogWorker do
  @moduledoc """
  Durable worker for bot event log writes.
  """

  use Oban.Worker,
    queue: :bots,
    max_attempts: 5,
    tags: ["bots", "event_log"]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.seconds(30),
    cap_seconds: 30 * 60,
    step_seconds: 30

  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Observability

  require Logger

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:cancel, String.t()} | {:error, term()}
  def perform(%Oban.Job{
        args: %{
          "bot_id" => bot_id,
          "event_type" => event_type,
          "channel" => channel,
          "metadata" => metadata
        }
      }) do
    Observability.span(
      [:retro_hex_chat, :bots, :event_log, :write],
      %{bot_id: bot_id, event_type: event_type, channel: channel},
      fn -> write_event(bot_id, event_type, channel, metadata || %{}) end,
      &write_result_metadata/1
    )
  end

  @spec write_event(integer(), String.t(), String.t() | nil, map()) ::
          :ok | {:cancel, String.t()} | {:error, term()}
  defp write_event(bot_id, event_type, channel, metadata) do
    case Queries.get_bot(bot_id) do
      nil ->
        Logger.info("bot_event_log_cancel bot_id=#{bot_id} reason=bot_not_found")
        {:cancel, "bot not found"}

      _bot ->
        case Queries.log_event(bot_id, event_type, channel, metadata) do
          {:ok, _event} ->
            Logger.debug("bot_event_log_write bot_id=#{bot_id} event_type=#{event_type}")
            :ok

          {:error, changeset} ->
            Logger.warning(
              "bot_event_log_error bot_id=#{bot_id} event_type=#{event_type} reason=changeset_error"
            )

            {:error, changeset}
        end
    end
  end

  defp write_result_metadata(:ok), do: %{result: "ok", events_written: 1}
  defp write_result_metadata({:cancel, reason}), do: %{result: "cancel", reason: reason}

  defp write_result_metadata({:error, %Ecto.Changeset{}}),
    do: %{result: "error", reason: "changeset_error"}

  defp write_result_metadata({:error, reason}), do: %{result: "error", reason: inspect(reason)}
end
