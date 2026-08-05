defmodule RetroHexChat.Jobs.RSSPollWorker do
  @moduledoc """
  Durable RSS feed polling.

  Fetching and parsing happen outside the database lock. The decoded result is
  then applied against the latest bot row under `FOR UPDATE`, so a duplicate job
  cannot plan the same items from stale `seen` state.
  """

  use Oban.Worker,
    queue: :rss,
    max_attempts: 5,
    tags: ["bots", "rss"],
    unique: [
      fields: [:worker, :queue, :args],
      keys: [:bot_id, :feed_id],
      states: :incomplete,
      period: :infinity
    ],
    replace: [
      available: [:scheduled_at],
      scheduled: [:scheduled_at]
    ]

  import Ecto.Query

  alias RetroHexChat.Bots.Bot
  alias RetroHexChat.Bots.Capabilities.RSS
  alias RetroHexChat.Bots.Capabilities.RSS.Scheduler
  alias RetroHexChat.Bots.Output
  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Bots.Server
  alias RetroHexChat.Observability
  alias RetroHexChat.Repo

  require Logger

  @rss_capability "rss"
  @timeout_ms 45_000

  @impl Oban.Worker
  def timeout(_job), do: @timeout_ms

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    min(30 * 60, attempt * attempt * 60)
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:cancel, String.t()} | {:error, term()}
  def perform(%Oban.Job{args: %{"bot_id" => bot_id, "feed_id" => feed_id}}) do
    Observability.span(
      [:retro_hex_chat, :bots, :rss, :poll],
      %{bot_id: bot_id, feed_id: feed_id},
      fn -> do_perform(bot_id, feed_id) end,
      &poll_result_metadata/1
    )
  end

  @spec do_perform(integer(), String.t()) :: :ok | {:cancel, String.t()} | {:error, term()}
  defp do_perform(bot_id, feed_id) do
    Logger.info("rss_poll_start bot_id=#{bot_id} feed_id=#{feed_id}")

    with {:ok, bot, feed} <- load_poll_target(bot_id, feed_id),
         decoded <- feed |> RSS.fetch_feed() |> RSS.decode_fetch_result(feed),
         {:ok, poll} <- persist_decoded_result(bot.id, feed_id, decoded),
         :ok <- deliver_poll(poll),
         :ok <- schedule_next_poll(poll) do
      Logger.info(log_line("rss_poll_stop", poll))
      :ok
    else
      {:cancel, reason} ->
        Logger.info(
          "rss_poll_cancel bot_id=#{bot_id} feed_id=#{feed_id} reason=#{log_value(reason)}"
        )

        {:cancel, reason}

      {:error, reason} ->
        Logger.warning(
          "rss_poll_error bot_id=#{bot_id} feed_id=#{feed_id} reason=#{log_value(reason)}"
        )

        {:error, reason}
    end
  end

  @spec load_poll_target(integer(), String.t()) :: {:ok, Bot.t(), map()} | {:cancel, String.t()}
  defp load_poll_target(bot_id, feed_id) do
    case Queries.get_bot(bot_id) do
      nil ->
        {:cancel, "bot not found"}

      %Bot{enabled: false} ->
        {:cancel, "bot disabled"}

      %Bot{} = bot ->
        with {:ok, rss_config} <- enabled_rss_config(bot),
             {:ok, feed} <- find_feed(rss_config, feed_id) do
          Observability.set_current_span_attributes(%{
            bot: bot.nickname,
            channel: feed["channel"],
            feed_url: feed["url"]
          })

          Logger.info(
            "rss_poll_target bot_id=#{bot.id} bot=#{bot.nickname} feed_id=#{feed_id} " <>
              "channel=#{feed["channel"]} url=#{feed["url"]}"
          )

          {:ok, bot, feed}
        end
    end
  end

  @spec persist_decoded_result(integer(), String.t(), RSS.decoded_feed_result()) ::
          {:ok, map()} | {:cancel, String.t()} | {:error, term()}
  defp persist_decoded_result(bot_id, feed_id, decoded) do
    case Repo.transaction(fn -> apply_under_lock(bot_id, feed_id, decoded) end) do
      {:ok, {:ok, poll}} -> {:ok, poll}
      {:ok, {:cancel, reason}} -> {:cancel, reason}
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec apply_under_lock(integer(), String.t(), RSS.decoded_feed_result()) ::
          {:ok, map()} | {:cancel, String.t()} | {:error, term()}
  defp apply_under_lock(bot_id, feed_id, decoded) do
    with %Bot{} = bot <- lock_bot(bot_id),
         true <- bot.enabled,
         {:ok, rss_config} <- enabled_rss_config(bot),
         {:ok, feed} <- find_feed(rss_config, feed_id) do
      state = RSS.init_state(rss_config)
      {planned, new_state} = RSS.apply_decoded_result(feed, decoded, state, rss_config)
      summary = poll_summary(feed, decoded, planned, new_state)

      case persist_rss_state(bot, rss_config, new_state) do
        {:ok, updated_bot} ->
          Observability.set_current_span_attributes(summary)

          {:ok,
           %{
             bot: updated_bot,
             channel: feed["channel"],
             feed_id: feed_id,
             feed_url: feed["url"],
             planned: planned,
             poll_interval_ms: new_state.poll_interval_ms,
             summary: summary
           }}

        {:error, reason} ->
          {:error, reason}
      end
    else
      nil -> {:cancel, "bot not found"}
      false -> {:cancel, "bot disabled"}
      {:cancel, reason} -> {:cancel, reason}
    end
  end

  @spec lock_bot(integer()) :: Bot.t() | nil
  defp lock_bot(bot_id) do
    Bot
    |> where([bot], bot.id == ^bot_id)
    |> lock("FOR UPDATE")
    |> Repo.one()
  end

  @spec enabled_rss_config(Bot.t()) :: {:ok, map()} | {:cancel, String.t()}
  defp enabled_rss_config(%Bot{capabilities: capabilities}) do
    case Map.get(capabilities || %{}, @rss_capability) do
      %{"enabled" => false} -> {:cancel, "rss disabled"}
      config when is_map(config) -> {:ok, config}
      _other -> {:cancel, "rss not configured"}
    end
  end

  @spec find_feed(map(), String.t()) :: {:ok, map()} | {:cancel, String.t()}
  defp find_feed(rss_config, feed_id) do
    rss_config
    |> RSS.init_state()
    |> Map.fetch!(:feeds)
    |> Enum.find(&(&1["id"] == feed_id))
    |> case do
      nil -> {:cancel, "feed removed"}
      feed -> {:ok, feed}
    end
  end

  @spec persist_rss_state(Bot.t(), map(), map()) :: {:ok, Bot.t()} | {:error, term()}
  defp persist_rss_state(bot, rss_config, new_state) do
    updated_rss = Map.merge(rss_config, %{"feeds" => new_state.feeds})
    capabilities = Map.put(bot.capabilities || %{}, @rss_capability, updated_rss)

    case Queries.update_bot(bot, %{capabilities: capabilities}) do
      {:ok, updated_bot} -> {:ok, updated_bot}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec deliver_poll(map()) :: :ok | {:error, term()}
  defp deliver_poll(%{planned: :ignore, bot: bot}) do
    sync_running_bot(bot)
  end

  defp deliver_poll(%{planned: planned, bot: bot, channel: channel}) do
    sync_running_bot(bot)

    case RSS.format_planned_result(planned) do
      {:multi_output, outputs} ->
        result = Output.send_many(channel, bot.nickname, outputs)

        Logger.info(
          "rss_poll_deliver bot=#{bot.nickname} channel=#{channel} count=#{length(outputs)}"
        )

        result

      :ignore ->
        :ok
    end
  end

  @spec sync_running_bot(Bot.t()) :: :ok
  defp sync_running_bot(bot) do
    Server.sync_capabilities(bot.nickname, bot.capabilities)
  catch
    :exit, _reason -> :ok
  end

  @spec schedule_next_poll(map()) :: :ok | {:error, term()}
  defp schedule_next_poll(%{bot: %Bot{id: bot_id}, feed_id: feed_id, poll_interval_ms: delay_ms}) do
    Scheduler.schedule_follow_up_poll(bot_id, feed_id, delay_ms)
  end

  @spec poll_summary(map(), RSS.decoded_feed_result(), RSS.planned_result(), map()) :: map()
  defp poll_summary(feed, decoded, planned, new_state) do
    published_count = published_count(planned)
    source_item_count = decoded_item_count(decoded)
    status = poll_status(feed, decoded, published_count, source_item_count)
    updated_feed = Enum.find(new_state.feeds, &(&1["id"] == feed["id"])) || feed

    %{
      channel: feed["channel"],
      feed_url: feed["url"],
      poll_status: status,
      source_item_count: source_item_count,
      published_count: published_count,
      seen_count: length(updated_feed["seen"] || []),
      next_poll_ms: new_state.poll_interval_ms,
      last_error: updated_feed["last_error"]
    }
  end

  @spec poll_status(map(), RSS.decoded_feed_result(), non_neg_integer(), non_neg_integer()) ::
          String.t()
  defp poll_status(_feed, {:error, _reason}, _published_count, _source_item_count),
    do: "feed_error"

  defp poll_status(_feed, {:not_modified}, _published_count, _source_item_count),
    do: "not_modified"

  defp poll_status(_feed, _decoded, published_count, _source_item_count) when published_count > 0,
    do: "published"

  defp poll_status(feed, _decoded, _published_count, source_item_count) do
    if (feed["seen"] || []) == [] and source_item_count > 0 do
      "seeded_baseline"
    else
      "no_new_items"
    end
  end

  @spec decoded_item_count(RSS.decoded_feed_result()) :: non_neg_integer()
  defp decoded_item_count({:ok, %{items: items}, _headers}) when is_list(items), do: length(items)
  defp decoded_item_count(_decoded), do: 0

  @spec published_count(RSS.planned_result()) :: non_neg_integer()
  defp published_count({:items, items, _feed_title}), do: length(items)
  defp published_count(:ignore), do: 0

  @spec poll_result_metadata(:ok | {:cancel, term()} | {:error, term()}) :: map()
  defp poll_result_metadata(:ok), do: %{result: "ok"}
  defp poll_result_metadata({:cancel, reason}), do: %{result: "cancel", reason: log_value(reason)}
  defp poll_result_metadata({:error, reason}), do: %{result: "error", reason: log_value(reason)}

  @spec log_line(String.t(), map()) :: String.t()
  defp log_line(event, poll) do
    summary = Map.get(poll, :summary, %{})
    bot = poll.bot

    [
      event,
      "bot_id=#{bot.id}",
      "bot=#{bot.nickname}",
      "feed_id=#{poll.feed_id}",
      "channel=#{poll.channel}",
      "url=#{poll.feed_url}",
      "status=#{Map.get(summary, :poll_status)}",
      "source_items=#{Map.get(summary, :source_item_count)}",
      "published=#{Map.get(summary, :published_count)}",
      "seen=#{Map.get(summary, :seen_count)}",
      "next_poll_ms=#{Map.get(summary, :next_poll_ms)}",
      "last_error=#{log_value(Map.get(summary, :last_error))}"
    ]
    |> Enum.join(" ")
  end

  @spec log_value(term()) :: String.t()
  defp log_value(nil), do: "none"
  defp log_value(value) when is_binary(value), do: value |> String.replace(~r/\s+/, "_")
  defp log_value(value) when is_atom(value), do: Atom.to_string(value)
  defp log_value(value), do: value |> inspect() |> String.replace(~r/\s+/, "_")
end
