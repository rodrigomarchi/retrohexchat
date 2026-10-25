defmodule RetroHexChat.Jobs.BotGreetingPruneWorker do
  @moduledoc """
  Lets a greeter forget people it has not seen in a long time.

  The record of who a bot has welcomed is what keeps a room from announcing the
  same person on every reconnect, and it has to survive a restart to do that. It
  also grows with nicknames rather than with people — a guest picks a new one
  whenever they like — so without this it is a table that only ever accumulates.

  Forgetting is not a loss here. The row's remaining job after the repeat window
  has passed is suppressing one public line, and somebody who has been away for
  a season is somebody the room may as well greet again.
  """

  use RetroHexChat.Jobs.MaintenanceWorker,
    tags: ["bots"]

  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Observability

  @default_limit 500

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, map()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    limit = WorkerArgs.positive_integer(args, "limit", @default_limit)

    Observability.span(
      [:retro_hex_chat, :bots, :greetings, :prune],
      %{limit: limit},
      fn -> {:ok, Queries.prune_greetings(limit: limit)} end,
      ResultMetadata.summary([:candidates, :deleted])
    )
  end
end
