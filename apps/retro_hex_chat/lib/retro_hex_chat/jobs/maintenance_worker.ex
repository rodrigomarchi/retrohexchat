defmodule RetroHexChat.Jobs.MaintenanceWorker do
  @moduledoc """
  The shape every maintenance sweep shares: the `:maintenance` queue, three
  attempts, one job of its kind pending at a time, and `Jobs.Retry`'s timeout
  and backoff. A worker states only what is its own — its tags, and any value
  that differs from the defaults below.

      use RetroHexChat.Jobs.MaintenanceWorker,
        tags: ["trusted_devices"],
        timeout: :timer.minutes(2)

  Options, with their defaults: `:tags` (required; `"maintenance"` is added),
  `:unique_fields` (`[:worker, :queue]`), `:unique_keys` (none), `:period`
  (`60` seconds, or `:infinity`), `:timeout` (one minute), `:cap_seconds`
  (`15 * 60`) and `:step_seconds` (`60`).
  """

  @doc false
  defmacro __using__(opts) do
    tags = ["maintenance" | Keyword.fetch!(opts, :tags)]
    fields = Keyword.get(opts, :unique_fields, [:worker, :queue])
    period = Keyword.get(opts, :period, 60)

    unique =
      case Keyword.get(opts, :unique_keys) do
        nil -> [fields: fields, states: :incomplete, period: period]
        keys -> [fields: fields, keys: keys, states: :incomplete, period: period]
      end

    timeout = Keyword.get(opts, :timeout, quote(do: :timer.minutes(1)))
    cap_seconds = Keyword.get(opts, :cap_seconds, 15 * 60)
    step_seconds = Keyword.get(opts, :step_seconds, 60)

    quote do
      use Oban.Worker,
        queue: :maintenance,
        max_attempts: 3,
        tags: unquote(tags),
        unique: unquote(unique)

      use RetroHexChat.Jobs.Retry,
        timeout: unquote(timeout),
        cap_seconds: unquote(cap_seconds),
        step_seconds: unquote(step_seconds)
    end
  end
end
