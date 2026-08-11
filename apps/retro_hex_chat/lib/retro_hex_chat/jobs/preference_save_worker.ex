defmodule RetroHexChat.Jobs.PreferenceSaveWorker do
  @moduledoc """
  Durable worker for registered-user preference and list persistence.
  """

  use Oban.Worker,
    queue: :persistence,
    max_attempts: 5,
    tags: ["persistence"],
    unique: [
      fields: [:worker, :queue, :args],
      keys: [:owner_nickname, :preference_type],
      states: :incomplete,
      period: :infinity
    ],
    replace: [
      available: [:scheduled_at],
      scheduled: [:scheduled_at],
      retryable: [:scheduled_at]
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.seconds(30),
    cap_seconds: 10 * 60,
    step_seconds: 15

  alias RetroHexChat.Chat.PreferencePersistence
  alias RetroHexChat.Observability

  require Logger

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) ::
          {:ok, :applied | :already_applied} | {:cancel, String.t()} | {:error, term()}
  def perform(
        %Oban.Job{
          args: %{"owner_nickname" => owner_nickname, "preference_type" => preference_type}
        } = job
      ) do
    Observability.span(
      [:retro_hex_chat, :persistence, :save],
      %{preference_type: preference_type, attempt: job.attempt},
      fn ->
        PreferencePersistence.apply_pending(owner_nickname, preference_type, attempt: job.attempt)
      end,
      &save_result_metadata/1
    )
  end

  defp save_result_metadata({:ok, :applied}), do: %{result: "ok"}
  defp save_result_metadata({:ok, :already_applied}), do: %{result: "noop"}
  defp save_result_metadata({:cancel, reason}), do: %{result: "cancel", reason: reason}

  defp save_result_metadata({:error, %Ecto.Changeset{}}),
    do: %{result: "error", reason: "changeset_error"}

  defp save_result_metadata({:error, reason}), do: %{result: "error", reason: log_reason(reason)}

  defp log_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp log_reason(reason) when is_binary(reason), do: reason
  defp log_reason(_reason), do: "unknown"
end
