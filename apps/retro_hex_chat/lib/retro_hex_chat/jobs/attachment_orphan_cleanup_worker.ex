defmodule RetroHexChat.Jobs.AttachmentOrphanCleanupWorker do
  @moduledoc """
  Cleans reserved/uploaded attachment objects that never became chat attachments.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "attachments"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: 60
    ]

  alias RetroHexChat.Chat.Attachments
  alias RetroHexChat.Observability

  @timeout_ms 120_000
  @default_limit 100
  @default_orphan_age_seconds :timer.hours(1) |> div(1_000)

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  def backoff(%Oban.Job{attempt: attempt}) do
    min(15 * 60, attempt * attempt * 60)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, Attachments.cleanup_summary()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    limit = positive_arg(args, "limit", @default_limit)
    orphan_age_seconds = positive_arg(args, "orphan_age_seconds", @default_orphan_age_seconds)

    Observability.span(
      [:retro_hex_chat, :attachments, :orphan_cleanup],
      %{limit: limit, orphan_age_seconds: orphan_age_seconds},
      fn ->
        Attachments.cleanup_orphan_uploads(
          limit: limit,
          orphan_age_seconds: orphan_age_seconds
        )
      end,
      &cleanup_result_metadata/1
    )
  end

  defp positive_arg(args, key, default) do
    case Map.get(args, key) do
      value when is_integer(value) and value > 0 -> value
      _value -> default
    end
  end

  defp cleanup_result_metadata({:ok, summary}) do
    %{
      result: "ok",
      candidates: summary.candidates,
      deleted: summary.deleted,
      skipped: summary.skipped,
      bytes_deleted: summary.bytes_deleted
    }
  end

  defp cleanup_result_metadata({:error, reason}) do
    %{result: "error", reason: error_reason(reason)}
  end

  defp error_reason(%Ecto.Changeset{}), do: "changeset_error"
  defp error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp error_reason(reason) when is_binary(reason), do: reason
  defp error_reason(%module{}), do: module |> Module.split() |> List.last()
  defp error_reason(_reason), do: "unknown"
end
