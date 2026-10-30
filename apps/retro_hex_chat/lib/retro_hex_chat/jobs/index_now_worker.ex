defmodule RetroHexChat.Jobs.IndexNowWorker do
  @moduledoc """
  Announces the public pages that changed, so search engines fetch them now.

  It runs at every boot, for the pages whose content changed in the last two
  days. A page's day comes from the files it is written in, so the release that
  ships an edit carries a recent day and is announced by the boot that starts
  it. A restart re-announces the same short list, which engines take without
  complaint.

  `"since"` may be passed as an ISO date to announce another window by hand.

  Refusals (400, 403, 422 — a bad key, a URL off the host) are cancelled, since
  resending the same list gets the same answer; throttling and server errors
  retry. A key the engines have not verified yet — every key, in the first
  minutes after it is published — snoozes the job an hour at a time, and gives
  up after six tries with that reason on the job.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["seo", "index_now"],
    unique: [period: 5 * 60]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(2),
    cap_seconds: 30 * 60,
    step_seconds: 60

  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Net.HTTPRetry
  alias RetroHexChat.Observability
  alias RetroHexChat.SEO.IndexNow

  @deploy_window_days 2
  @verification_wait_seconds 60 * 60
  @verification_snoozes 5

  @type outcome ::
          {:ok, IndexNow.summary() | :disabled}
          | {:error, IndexNow.reason()}
          | {:snooze, pos_integer()}
          | {:cancel, String.t()}

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: outcome()
  def perform(%Oban.Job{args: args, meta: meta}) do
    snoozed = Map.get(meta || %{}, "snoozed", 0)

    Observability.span(
      [:retro_hex_chat, :seo, :index_now, :submit],
      %{scope: Map.get(args, "scope", "unknown")},
      fn -> announce(args, snoozed) end,
      &result_metadata/1
    )
  end

  @spec announce(map(), non_neg_integer()) :: outcome()
  defp announce(args, snoozed) do
    if IndexNow.enabled?() do
      case urls(args) do
        {:ok, urls} -> urls |> IndexNow.submit() |> settle(snoozed)
        {:cancel, reason} -> {:cancel, reason}
      end
    else
      {:ok, :disabled}
    end
  end

  @spec urls(map()) :: {:ok, [String.t()]} | {:cancel, String.t()}
  defp urls(%{"scope" => "deploy"} = args) do
    with {:ok, since} <- date(args, "since", -@deploy_window_days) do
      {:ok, source().pages_changed_since(since)}
    end
  end

  defp urls(_args), do: {:cancel, "unknown_scope"}

  @spec date(map(), String.t(), integer()) :: {:ok, Date.t()} | {:cancel, String.t()}
  defp date(args, key, default_offset_days) do
    case Map.fetch(args, key) do
      :error ->
        {:ok, Date.add(Date.utc_today(), default_offset_days)}

      {:ok, value} ->
        case Date.from_iso8601(to_string(value)) do
          {:ok, date} -> {:ok, date}
          {:error, _reason} -> {:cancel, "invalid_#{key}"}
        end
    end
  end

  # A snooze is not an attempt: Oban counts snoozes in `meta["snoozed"]`, and
  # that count bounds the wait for the key to be verified.
  @spec settle({:ok, IndexNow.summary()} | {:error, IndexNow.reason()}, non_neg_integer()) ::
          outcome()
  defp settle({:ok, summary}, _snoozed), do: {:ok, summary}

  defp settle({:error, :verification_pending}, snoozed) when snoozed < @verification_snoozes,
    do: {:snooze, @verification_wait_seconds}

  defp settle({:error, reason}, _snoozed) do
    if HTTPRetry.retryable?(reason),
      do: {:error, reason},
      else: {:cancel, ResultMetadata.error_reason(reason)}
  end

  @spec source() :: module()
  defp source do
    :retro_hex_chat |> Application.get_env(:index_now, []) |> Keyword.fetch!(:url_source)
  end

  @spec result_metadata(outcome()) :: map()
  defp result_metadata({:ok, :disabled}), do: %{result: "disabled"}
  defp result_metadata({:ok, %{submitted: 0}}), do: %{result: "nothing", url_count: 0}

  defp result_metadata({:ok, %{submitted: count, batches: batches}}),
    do: %{result: "ok", url_count: count, batch_count: batches}

  defp result_metadata({:cancel, reason}), do: %{result: "cancel", reason: reason}

  defp result_metadata({:snooze, _seconds}),
    do: %{result: "snooze", reason: "verification_pending"}

  defp result_metadata({:error, reason}),
    do: %{result: "error", reason: ResultMetadata.error_reason(reason)}
end
