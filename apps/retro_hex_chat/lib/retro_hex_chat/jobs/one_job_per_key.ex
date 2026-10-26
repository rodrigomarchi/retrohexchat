defmodule RetroHexChat.Jobs.OneJobPerKey do
  @moduledoc """
  An Oban worker that keeps at most one pending job per key: enqueueing again
  for the same `keys` while a job waits moves that job's `scheduled_at`
  instead of adding a second one.

      use RetroHexChat.Jobs.OneJobPerKey,
        queue: :rss,
        max_attempts: 3,
        tags: ["bots", "rss"],
        keys: [:bot_id, :feed_id]

  `reschedule` lists the states whose jobs move (default: available and
  scheduled); every other option goes to `use Oban.Worker` as it is.
  """

  @doc false
  defmacro __using__(opts) do
    keys = Keyword.fetch!(opts, :keys)
    reschedule = Keyword.get(opts, :reschedule, [:available, :scheduled])

    oban =
      opts
      |> Keyword.drop([:keys, :reschedule])
      |> Keyword.merge(
        unique: [
          fields: [:worker, :queue, :args],
          keys: keys,
          states: :incomplete,
          period: :infinity
        ],
        replace: Enum.map(reschedule, &{&1, [:scheduled_at]})
      )

    quote do
      use Oban.Worker, unquote(oban)
    end
  end
end
