defmodule RetroHexChat.Jobs.MuteExpiry do
  @moduledoc """
  One timed mute reaching its end — in a channel or across the server. The
  job carries the mute's id; the mute's own module decides whether it is due
  (`expire_due/1`), and the worker says what lifting it means where it lived.
  A mute that is not yet due snoozes the job until it is.
  """

  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability

  @type outcome ::
          {:ok, :expired | :noop}
          | {:snooze, pos_integer()}
          | {:cancel, String.t()}
          | {:error, term()}

  @doc """
  Runs one expiry inside the `event` span. `kind` names the mute in a
  cancellation ("channel mute"), `expire_due` is the mute module's, and
  `lifted` is called with the expired mute.
  """
  @spec run(
          [atom()],
          String.t(),
          term(),
          (pos_integer() -> {:ok, tuple()} | {:error, term()}),
          (map() -> term())
        ) ::
          outcome()
  def run(event, kind, raw_id, expire_due, lifted) do
    Observability.span(
      event,
      %{mute_id: raw_id},
      fn -> expire(WorkerArgs.positive_id(raw_id), kind, expire_due, lifted) end,
      &ResultMetadata.expiry/1
    )
  end

  defp expire({:ok, mute_id}, kind, expire_due, lifted) do
    case expire_due.(mute_id) do
      {:ok, {:expired, mute}} ->
        lifted.(mute)
        {:ok, :expired}

      {:ok, {:noop, _mute}} ->
        {:ok, :noop}

      {:ok, {:not_due, _mute, seconds}} ->
        {:snooze, seconds}

      {:error, :not_found} ->
        {:cancel, "#{kind} not found"}

      {:error, :permanent_restriction} ->
        {:cancel, "#{kind} is permanent"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp expire(:error, kind, _expire_due, _lifted), do: {:cancel, "invalid #{kind} id"}
end
