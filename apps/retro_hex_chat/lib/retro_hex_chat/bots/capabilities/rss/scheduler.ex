defmodule RetroHexChat.Bots.Capabilities.RSS.Scheduler do
  @moduledoc """
  Scheduling boundary for RSS polling.

  The capability asks for a feed poll to exist; the implementation decides how
  that work is made durable. Production uses Oban, while tests may swap the
  module without touching RSS parsing or command handling.
  """

  @callback schedule_poll(integer(), String.t(), non_neg_integer()) :: :ok | {:error, term()}
  @callback cancel_poll(integer(), String.t()) :: :ok | {:error, term()}

  @doc "Ensure a durable RSS poll job exists after `delay_ms`."
  @spec schedule_poll(integer() | nil, String.t() | nil, non_neg_integer()) ::
          :ok | {:error, term()}
  def schedule_poll(bot_id, feed_id, delay_ms)
      when is_integer(bot_id) and is_binary(feed_id) and is_integer(delay_ms) and delay_ms >= 0 do
    impl().schedule_poll(bot_id, feed_id, delay_ms)
  end

  def schedule_poll(_bot_id, _feed_id, _delay_ms), do: {:error, :invalid_rss_poll}

  @doc "Cancel incomplete durable RSS poll jobs for a feed."
  @spec cancel_poll(integer() | nil, String.t() | nil) :: :ok | {:error, term()}
  def cancel_poll(bot_id, feed_id) when is_integer(bot_id) and is_binary(feed_id) do
    impl().cancel_poll(bot_id, feed_id)
  end

  def cancel_poll(_bot_id, _feed_id), do: :ok

  @doc false
  @spec impl() :: module()
  def impl do
    Application.get_env(
      :retro_hex_chat,
      :rss_poll_scheduler,
      RetroHexChat.Bots.Capabilities.RSS.Scheduler.Oban
    )
  end
end

defmodule RetroHexChat.Bots.Capabilities.RSS.Scheduler.Oban do
  @moduledoc false

  alias RetroHexChat.Jobs
  alias RetroHexChat.Jobs.RSSPollWorker

  @behaviour RetroHexChat.Bots.Capabilities.RSS.Scheduler

  @impl true
  @spec schedule_poll(integer(), String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def schedule_poll(bot_id, feed_id, delay_ms) do
    delay_s = delay_ms |> div(1_000) |> max(1)

    %{bot_id: bot_id, feed_id: feed_id}
    |> RSSPollWorker.new(schedule_in: delay_s)
    |> Jobs.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  @spec cancel_poll(integer(), String.t()) :: :ok | {:error, term()}
  def cancel_poll(bot_id, feed_id) do
    {:ok, _count} =
      Jobs.cancel_worker_jobs(RSSPollWorker, :rss, %{"bot_id" => bot_id, "feed_id" => feed_id})

    :ok
  end
end
