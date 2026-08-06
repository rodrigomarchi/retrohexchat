defmodule RetroHexChat.Jobs.GlobalMuteExpiryWorker do
  @moduledoc """
  Expires temporary server-wide mutes.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "global_mutes"],
    unique: [
      fields: [:worker, :queue, :args],
      keys: [:mute_id],
      states: :incomplete,
      period: :infinity
    ]

  alias RetroHexChat.Admin.GlobalMutes
  alias RetroHexChat.Observability

  @pubsub RetroHexChat.PubSub
  @timeout_ms 30_000

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  def backoff(%Oban.Job{attempt: attempt}) do
    min(15 * 60, attempt * attempt * 30)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) ::
          {:ok, :expired | :noop}
          | {:snooze, pos_integer()}
          | {:cancel, String.t()}
          | {:error, term()}
  def perform(%Oban.Job{args: %{"mute_id" => mute_id}}) do
    Observability.span(
      [:retro_hex_chat, :admin, :global_mutes, :expire],
      %{mute_id: mute_id},
      fn -> expire(parse_mute_id(mute_id)) end,
      &expiry_result_metadata/1
    )
  end

  defp expire({:ok, mute_id}) do
    case GlobalMutes.expire_due(mute_id) do
      {:ok, {:expired, mute}} ->
        broadcast_unmuted(mute.nickname)
        {:ok, :expired}

      {:ok, {:noop, _mute}} ->
        {:ok, :noop}

      {:ok, {:not_due, _mute, seconds}} ->
        {:snooze, seconds}

      {:error, :not_found} ->
        {:cancel, "global mute not found"}

      {:error, :permanent_mute} ->
        {:cancel, "global mute is permanent"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp expire(:error), do: {:cancel, "invalid global mute id"}

  defp broadcast_unmuted(nickname) do
    Phoenix.PubSub.broadcast(@pubsub, "user:#{nickname}", {:user_unmuted, %{nickname: nickname}})
  end

  defp parse_mute_id(mute_id) when is_integer(mute_id) and mute_id > 0, do: {:ok, mute_id}

  defp parse_mute_id(mute_id) when is_binary(mute_id) do
    case Integer.parse(mute_id) do
      {id, ""} when id > 0 -> {:ok, id}
      _result -> :error
    end
  end

  defp parse_mute_id(_mute_id), do: :error

  defp expiry_result_metadata({:ok, :expired}), do: %{result: "expired", expired_count: 1}
  defp expiry_result_metadata({:ok, result}), do: %{result: Atom.to_string(result)}
  defp expiry_result_metadata({:snooze, seconds}), do: %{result: "snooze", seconds: seconds}
  defp expiry_result_metadata({:cancel, reason}), do: %{result: "cancel", reason: reason}

  defp expiry_result_metadata({:error, %Ecto.Changeset{}}),
    do: %{result: "error", reason: "changeset_error"}

  defp expiry_result_metadata({:error, reason}) when is_atom(reason),
    do: %{result: "error", reason: Atom.to_string(reason)}

  defp expiry_result_metadata({:error, reason}) when is_binary(reason),
    do: %{result: "error", reason: reason}

  defp expiry_result_metadata({:error, _reason}), do: %{result: "error", reason: "unknown"}
end
