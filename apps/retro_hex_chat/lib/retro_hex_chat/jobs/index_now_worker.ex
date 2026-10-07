defmodule RetroHexChat.Jobs.IndexNowWorker do
  @moduledoc """
  Announces the public pages that changed, so search engines fetch them now.

  Two scopes, each with its own trigger in the cron table:

    * `"deploy"`, at every boot: the pages whose content changed in the last
      two days. A page's day comes from the files it is written in, so the
      release that ships an edit carries a recent day and is announced by the
      boot that starts it. A restart re-announces the same short list, which
      engines take without complaint.
    * `"archive"`, every night: yesterday's page of each published channel and
      the channel's index, the two pages a day of conversation adds.

  `"since"` (deploy) and `"date"` (archive) may be passed as ISO dates to
  announce another window by hand.

  Refusals (400, 403, 422 — a bad key, a URL off the host) are cancelled, since
  resending the same list gets the same answer; throttling and server errors
  retry.
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

  @type outcome ::
          {:ok, IndexNow.summary() | :disabled}
          | {:error, IndexNow.reason()}
          | {:cancel, String.t()}

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: outcome()
  def perform(%Oban.Job{args: args}) do
    Observability.span(
      [:retro_hex_chat, :seo, :index_now, :submit],
      %{scope: Map.get(args, "scope", "unknown")},
      fn -> announce(args) end,
      &result_metadata/1
    )
  end

  @spec announce(map()) :: outcome()
  defp announce(args) do
    if IndexNow.enabled?() do
      case urls(args) do
        {:ok, urls} -> urls |> IndexNow.submit() |> settle()
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

  defp urls(%{"scope" => "archive"} = args) do
    with {:ok, day} <- date(args, "date", -1) do
      {:ok, source().archive_day(day)}
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

  @spec settle({:ok, IndexNow.summary()} | {:error, IndexNow.reason()}) :: outcome()
  defp settle({:ok, summary}), do: {:ok, summary}

  defp settle({:error, reason}) do
    if HTTPRetry.retryable?(reason), do: {:error, reason}, else: {:cancel, reason_label(reason)}
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

  defp result_metadata({:error, reason}),
    do: %{result: "error", reason: reason_label(reason)}

  # A status is a label of its own; anything else goes through the shared names.
  @spec reason_label(term()) :: String.t()
  defp reason_label({:http_status, status}), do: "http_#{status}"
  defp reason_label(reason), do: ResultMetadata.error_reason(reason)
end
