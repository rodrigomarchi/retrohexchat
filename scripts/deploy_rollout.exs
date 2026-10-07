defmodule DeployRollout do
  @moduledoc """
  Confirms a deploy is live: production answers `/version` with the release
  that was just built, on every backend.

  `deploy.sh` ends when the release is written; DeployEx swaps it in a few
  seconds later and the new nodes take traffic about a minute after that.
  During the swap haproxy still sends some requests to a node on the old
  release, so one matching answer proves nothing. Confirmed is a run of
  consecutive matching answers; any other answer — the old version, an error,
  no answer — starts the count again.

  The expected version is read from `deploy.sh`'s own output (`==> Version:`),
  the exact string the release serves, never recomputed from a local checkout.

  Everything here is pure or takes its effects as arguments, so the tests run
  without a network, a clock or a sleep.
  """

  @default_required 10
  @default_interval_ms 3_000
  @default_timeout_ms 300_000

  @type fetch :: (-> {:ok, String.t()} | {:error, String.t()})
  @type result ::
          {:ok, %{version: String.t(), elapsed_ms: non_neg_integer(), polls: pos_integer()}}
          | {:error,
             %{reason: :timeout, last_seen: String.t() | nil, elapsed_ms: non_neg_integer()}}

  @doc "The release version `deploy.sh` printed, or `:error` when it printed none."
  @spec expected_version(String.t()) :: {:ok, String.t()} | :error
  def expected_version(deploy_output) do
    case Regex.run(~r/^==> Version: (\S+)/m, deploy_output) do
      [_, version] -> {:ok, version}
      nil -> :error
    end
  end

  @doc "The version in a `/version` response body, or `:error` for anything else."
  @spec served_version(String.t()) :: {:ok, String.t()} | :error
  def served_version(body) do
    case JSON.decode(body) do
      {:ok, %{"version" => version}} when is_binary(version) -> {:ok, version}
      _ -> :error
    end
  end

  @doc "The consecutive-match count after one more answer."
  @spec streak(non_neg_integer(), {:ok, String.t()} | :error, String.t()) :: non_neg_integer()
  def streak(count, {:ok, expected}, expected), do: count + 1
  def streak(_count, _answer, _expected), do: 0

  @doc """
  Polls until `required` consecutive answers name `expected`, or `timeout_ms` passes.

  Options: `:required`, `:interval_ms`, `:timeout_ms`, `:sleep` and `:now_ms`
  (both injectable), `:on_poll` (called with each answer, for progress).
  """
  @spec wait(fetch(), String.t(), keyword()) :: result()
  def wait(fetch, expected, opts \\ []) do
    now = Keyword.get(opts, :now_ms, fn -> System.monotonic_time(:millisecond) end)

    state = %{
      fetch: fetch,
      expected: expected,
      required: Keyword.get(opts, :required, @default_required),
      interval: Keyword.get(opts, :interval_ms, @default_interval_ms),
      deadline: now.() + Keyword.get(opts, :timeout_ms, @default_timeout_ms),
      started: now.(),
      now: now,
      sleep: Keyword.get(opts, :sleep, &Process.sleep/1),
      on_poll: Keyword.get(opts, :on_poll, fn _answer -> :ok end)
    }

    poll(state, 0, 0, nil)
  end

  defp poll(state, count, polls, last_seen) do
    answer =
      case state.fetch.() do
        {:ok, body} -> served_version(body)
        {:error, _reason} -> :error
      end

    state.on_poll.(answer)
    count = streak(count, answer, state.expected)
    polls = polls + 1
    last_seen = with({:ok, version} <- answer, do: version, else: (_ -> last_seen))
    elapsed = state.now.() - state.started

    cond do
      count >= state.required ->
        {:ok, %{version: state.expected, elapsed_ms: elapsed, polls: polls}}

      state.now.() + state.interval > state.deadline ->
        {:error, %{reason: :timeout, last_seen: last_seen, elapsed_ms: elapsed}}

      true ->
        state.sleep.(state.interval)
        poll(state, count, polls, last_seen)
    end
  end

  @doc "A fetch that asks `url` through curl, bypassing any cache."
  @spec curl_fetch(String.t()) :: fetch()
  def curl_fetch(url) do
    fn ->
      args = ["-fsS", "--max-time", "10", "-H", "Cache-Control: no-cache", url]

      case System.cmd("curl", args, stderr_to_stdout: true) do
        {body, 0} -> {:ok, body}
        {output, _status} -> {:error, String.trim(output)}
      end
    end
  end
end
