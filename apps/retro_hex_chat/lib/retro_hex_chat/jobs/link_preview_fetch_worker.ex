defmodule RetroHexChat.Jobs.LinkPreviewFetchWorker do
  @moduledoc """
  Durable worker for URL Catcher link preview fetches.
  """

  use Oban.Worker,
    queue: :link_preview,
    max_attempts: 3,
    tags: ["link_preview"],
    unique: [
      fields: [:worker, :queue, :args],
      keys: [:url_hash],
      states: :incomplete,
      period: :infinity
    ],
    replace: [
      available: [:scheduled_at],
      scheduled: [:scheduled_at]
    ]

  alias RetroHexChat.Chat.LinkPreview
  alias RetroHexChat.Chat.LinkPreview.{Cache, Results}
  alias RetroHexChat.Observability

  require Logger

  @timeout_ms 20_000

  @impl Oban.Worker
  @spec timeout(Oban.Job.t()) :: pos_integer()
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  @spec backoff(Oban.Job.t()) :: non_neg_integer()
  def backoff(%Oban.Job{attempt: attempt}) do
    min(5 * 60, attempt * attempt * 15)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, :fetched | :failed} | {:error, term()}
  def perform(%Oban.Job{args: %{"url" => url, "url_hash" => url_hash}} = job) do
    Observability.span(
      [:retro_hex_chat, :link_preview, :fetch],
      %{url_hash: url_hash, attempt: job.attempt},
      fn -> fetch(url, job) end,
      &fetch_result_metadata/1
    )
  end

  @spec fetch(String.t(), Oban.Job.t()) :: {:ok, :fetched | :failed} | {:error, term()}
  defp fetch(url, %Oban.Job{} = job) do
    Logger.info(
      "link_preview_fetch_start url_hash=#{job.args["url_hash"]} attempt=#{job.attempt}"
    )

    case LinkPreview.fetch_title_result(url) do
      {:ok, title} ->
        record_success(url, title, job)

      {:error, reason} ->
        record_error(url, reason, job)
    end
  end

  @spec record_success(String.t(), String.t(), Oban.Job.t()) ::
          {:ok, :fetched} | {:error, term()}
  defp record_success(url, title, job) do
    case Results.record_success(url, title, attempt: job.attempt) do
      {:ok, result} ->
        Cache.put(result.url, title)
        _ = LinkPreview.broadcast_result(result.url, {:ok, title})
        Observability.set_current_span_attributes(%{result: "ok", title_present?: true})
        Logger.info("link_preview_fetch_stop url_hash=#{result.url_hash} result=ok")
        {:ok, :fetched}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec record_error(String.t(), Results.fetch_error(), Oban.Job.t()) ::
          {:ok, :failed} | {:error, term()}
  defp record_error(url, reason, %Oban.Job{} = job) do
    if Results.retryable_error?(reason) and job.attempt < job.max_attempts do
      case Results.record_retryable_failure(url, reason, attempt: job.attempt) do
        {:ok, result} ->
          Logger.warning(
            "link_preview_fetch_retry url_hash=#{result.url_hash} reason=#{Results.error_reason(reason)} attempt=#{job.attempt}"
          )

          {:error, reason}

        {:error, store_error} ->
          {:error, store_error}
      end
    else
      record_final_error(url, reason, job)
    end
  end

  @spec record_final_error(String.t(), Results.fetch_error(), Oban.Job.t()) ::
          {:ok, :failed} | {:error, term()}
  defp record_final_error(url, reason, %Oban.Job{} = job) do
    case Results.record_failure(url, reason, attempt: job.attempt) do
      {:ok, result} ->
        Cache.put_error(result.url)
        _ = LinkPreview.broadcast_result(result.url, {:error, reason})

        Logger.info(
          "link_preview_fetch_stop url_hash=#{result.url_hash} result=failed reason=#{Results.error_reason(reason)} attempt=#{job.attempt}"
        )

        {:ok, :failed}

      {:error, store_error} ->
        {:error, store_error}
    end
  end

  defp fetch_result_metadata({:ok, :fetched}), do: %{result: "ok"}

  defp fetch_result_metadata({:ok, :failed}) do
    %{result: "failed"}
  end

  defp fetch_result_metadata({:error, reason}), do: %{result: "retry", reason: log_reason(reason)}

  defp log_reason({:http_status, status}) when is_integer(status), do: "http_#{status}"
  defp log_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp log_reason(%Ecto.Changeset{}), do: "changeset_error"
  defp log_reason(_reason), do: "unknown"
end
