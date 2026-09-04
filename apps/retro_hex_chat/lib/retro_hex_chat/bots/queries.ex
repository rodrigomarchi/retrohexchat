defmodule RetroHexChat.Bots.Queries do
  @moduledoc """
  CRUD operations for bot persistence.
  """

  import Ecto.Query

  alias RetroHexChat.Bots.{Bot, BotChannelConfig, BotCustomCommand, BotEventLog, BotGreeting}
  alias RetroHexChat.Page
  alias RetroHexChat.Repo

  # Curated lists: they grow only when an administrator creates an entry, never
  # from traffic, so they take a bound instead of a cursor. Set far above any
  # plausible real configuration — it exists so the query cannot be unbounded,
  # not to stop anyone.
  @max_curated 500

  # How long a bot remembers meeting somebody. Past this the room welcomes them
  # again, which for an absence measured in months is the right answer anyway.
  @greeting_retention_days 90

  # ── Bot CRUD ──────────────────────────────────────────────────

  @spec create_bot(map()) :: {:ok, Bot.t()} | {:error, Ecto.Changeset.t()}
  def create_bot(attrs) do
    %Bot{}
    |> Bot.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_bot(integer()) :: Bot.t() | nil
  def get_bot(id), do: Repo.get(Bot, id)

  @spec get_bot_by_name(String.t()) :: Bot.t() | nil
  def get_bot_by_name(name) do
    Repo.get_by(Bot, name: name)
  end

  @spec get_bot_by_nickname(String.t()) :: Bot.t() | nil
  def get_bot_by_nickname(nickname) do
    Repo.get_by(Bot, nickname: nickname)
  end

  @doc """
  Every bot on the server, alphabetical.

  Bounded rather than paginated: bots only exist because an administrator
  created one, so the list grows by decision, not by traffic. The bound also
  cannot be reached by accident — see `@max_curated`.
  """
  @spec list_bots() :: [Bot.t()]
  def list_bots do
    Bot |> order_by(:name) |> limit(@max_curated) |> Repo.all()
  end

  @doc """
  Every bot with its channels and custom commands loaded.

  What a roster has to answer before anything is clicked — where each bot works
  and how much it carries — is in the associations, so the list that shows it
  loads them once for everyone rather than per selected bot.
  """
  @spec list_bots_with_associations() :: [Bot.t()]
  def list_bots_with_associations do
    Bot
    |> order_by(:name)
    |> limit(@max_curated)
    |> preload([:channel_configs, :custom_commands])
    |> Repo.all()
  end

  @spec list_enabled_bots() :: [Bot.t()]
  def list_enabled_bots do
    Bot
    |> where(enabled: true)
    |> limit(@max_curated)
    |> preload([:channel_configs, :custom_commands])
    |> Repo.all()
  end

  @spec preload_associations(Bot.t()) :: Bot.t()
  def preload_associations(%Bot{} = bot) do
    Repo.preload(bot, [:channel_configs, :custom_commands])
  end

  @spec update_bot(Bot.t(), map()) :: {:ok, Bot.t()} | {:error, Ecto.Changeset.t()}
  def update_bot(%Bot{} = bot, attrs) do
    bot
    |> Bot.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_bot(Bot.t()) :: {:ok, Bot.t()} | {:error, Ecto.Changeset.t()}
  def delete_bot(%Bot{} = bot) do
    Repo.delete(bot)
  end

  # ── Channel Config ────────────────────────────────────────────

  @spec add_channel_config(integer(), String.t(), map()) ::
          {:ok, BotChannelConfig.t()} | {:error, Ecto.Changeset.t()}
  def add_channel_config(bot_id, channel_name, opts \\ %{}) do
    attrs = Map.merge(%{bot_id: bot_id, channel_name: channel_name}, opts)

    %BotChannelConfig{}
    |> BotChannelConfig.changeset(attrs)
    |> Repo.insert()
  end

  @spec remove_channel_config(integer(), String.t()) :: :ok
  def remove_channel_config(bot_id, channel_name) do
    BotChannelConfig
    |> where(bot_id: ^bot_id, channel_name: ^channel_name)
    |> Repo.delete_all()

    :ok
  end

  @doc "A bot's channel configuration. Bounded for the same reason as `list_bots/0`."
  @spec list_channel_configs(integer()) :: [BotChannelConfig.t()]
  def list_channel_configs(bot_id) do
    BotChannelConfig
    |> where(bot_id: ^bot_id)
    |> limit(@max_curated)
    |> order_by(:channel_name)
    |> Repo.all()
  end

  # ── Custom Commands ───────────────────────────────────────────

  @spec add_custom_command(integer(), map()) ::
          {:ok, BotCustomCommand.t()} | {:error, Ecto.Changeset.t()}
  def add_custom_command(bot_id, attrs) do
    %BotCustomCommand{}
    |> BotCustomCommand.changeset(Map.put(attrs, :bot_id, bot_id))
    |> Repo.insert(
      on_conflict: {:replace, [:response, :description, :enabled, :added_by, :updated_at]},
      conflict_target: [:bot_id, :trigger]
    )
  end

  @spec remove_custom_command(integer(), String.t()) :: :ok
  def remove_custom_command(bot_id, trigger) do
    BotCustomCommand
    |> where(bot_id: ^bot_id, trigger: ^trigger)
    |> Repo.delete_all()

    :ok
  end

  @doc "A bot's custom commands. Bounded for the same reason as `list_bots/0`."
  @spec list_custom_commands(integer()) :: [BotCustomCommand.t()]
  def list_custom_commands(bot_id) do
    BotCustomCommand
    |> where(bot_id: ^bot_id)
    |> limit(@max_curated)
    |> order_by(:trigger)
    |> Repo.all()
  end

  # ── Event Log ─────────────────────────────────────────────────

  @doc """
  One page of a bot's event log, newest first.

  Ordered by id rather than `inserted_at`: the log is append-only, so id order is
  the same chronology and gives a cursor that cannot tie or drift.
  """
  @spec list_event_logs(integer(), keyword()) :: Page.t()
  def list_event_logs(bot_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    BotEventLog
    |> where(bot_id: ^bot_id)
    |> maybe_before(Keyword.get(opts, :cursor))
    |> order_by([e], desc: e.id)
    |> limit(^Page.limit_with_lookahead(limit))
    |> Repo.all()
    |> Page.new(limit, & &1.id)
  end

  defp maybe_before(query, nil), do: query
  defp maybe_before(query, cursor), do: where(query, [e], e.id < ^cursor)

  @spec log_event(integer(), String.t(), String.t() | nil, map()) ::
          {:ok, BotEventLog.t()} | {:error, Ecto.Changeset.t()}
  def log_event(bot_id, event_type, channel \\ nil, metadata \\ %{}) do
    %BotEventLog{}
    |> BotEventLog.changeset(%{
      bot_id: bot_id,
      event_type: event_type,
      channel: channel,
      metadata: metadata
    })
    |> Repo.insert()
  end

  # ── Greeting ledger ───────────────────────────────────────────

  @doc """
  Records that `bot_id` is welcoming `nickname` into `channel`, and says what
  kind of welcome it has earned.

  Three answers, because a welcome has three cases and the caller has to tell
  them apart: somebody nobody has met, somebody last seen longer ago than the
  window, and somebody who was just here. They are decided by the write itself
  rather than by a read followed by a write — two people joining the same room
  in the same instant would both read "never greeted" and both be announced.

  `window_sec` of zero means there is no window: everyone is greeted again on
  every join, and only the announcement stays once per person.
  """
  @spec record_greeting(integer(), String.t(), String.t(), non_neg_integer()) ::
          :first_time | :window_elapsed | :within_window
  def record_greeting(bot_id, channel, nickname, window_sec) do
    now = DateTime.utc_now()
    channel_name = String.downcase(channel)
    normalized_nickname = String.downcase(nickname)

    inserted =
      Repo.insert_all(
        BotGreeting,
        [
          %{
            bot_id: bot_id,
            channel_name: channel_name,
            nickname: normalized_nickname,
            greeted_at: now,
            inserted_at: now,
            updated_at: now
          }
        ],
        on_conflict: :nothing,
        conflict_target: [:bot_id, :channel_name, :nickname]
      )

    case inserted do
      {1, _returned} ->
        :first_time

      _already_known ->
        refresh_greeting(bot_id, channel_name, normalized_nickname, now, window_sec)
    end
  end

  @spec refresh_greeting(
          integer(),
          String.t(),
          String.t(),
          DateTime.t(),
          non_neg_integer()
        ) :: :window_elapsed | :within_window
  defp refresh_greeting(bot_id, channel_name, nickname, now, window_sec) do
    cutoff = DateTime.add(now, -window_sec, :second)

    query =
      from g in BotGreeting,
        where: g.bot_id == ^bot_id,
        where: g.channel_name == ^channel_name,
        where: g.nickname == ^nickname,
        where: g.greeted_at <= ^cutoff

    case Repo.update_all(query, set: [greeted_at: now, updated_at: now]) do
      {0, _} -> :within_window
      {_updated, _} -> :window_elapsed
    end
  end

  @doc """
  Forgets greetings older than `before`, at most `limit` of them.

  Guest nicknames are chosen freely and never come back, so the ledger grows with
  names rather than with people. A row older than any repeat window has one job
  left — keeping the public announcement from repeating — and letting that go for
  somebody absent for months is the behaviour worth having anyway.
  """
  @spec delete_greetings_before(DateTime.t(), keyword()) :: non_neg_integer()
  def delete_greetings_before(%DateTime{} = before, opts \\ []) do
    limit = Keyword.get(opts, :limit, @max_curated)

    ids =
      from(g in BotGreeting,
        where: g.greeted_at < ^before,
        order_by: [asc: g.greeted_at],
        limit: ^limit,
        select: g.id
      )
      |> Repo.all()

    {deleted, _} = Repo.delete_all(from g in BotGreeting, where: g.id in ^ids)
    deleted
  end

  @doc """
  Forgets the oldest greetings past `retention_days`, at most `:limit` of them.

  A row's only job once the repeat window has passed is keeping the room from
  announcing the same person twice. Somebody absent for months is somebody the
  room may as well welcome again, so the record does not have to be kept for
  ever — and guest nicknames are chosen freely, so if it were, the table would
  grow with names nobody will use again.
  """
  @spec prune_greetings(keyword()) :: %{
          candidates: non_neg_integer(),
          deleted: non_neg_integer(),
          cutoff: DateTime.t()
        }
  def prune_greetings(opts \\ []) do
    retention_days = Keyword.get(opts, :retention_days, @greeting_retention_days)
    limit = Keyword.get(opts, :limit, @max_curated)
    cutoff = DateTime.add(DateTime.utc_now(), -retention_days * 24 * 60 * 60, :second)

    %{
      candidates: count_greetings_before(cutoff),
      deleted: delete_greetings_before(cutoff, limit: limit),
      cutoff: cutoff
    }
  end

  @doc "How many greetings are older than `before`."
  @spec count_greetings_before(DateTime.t()) :: non_neg_integer()
  def count_greetings_before(%DateTime{} = before) do
    Repo.aggregate(from(g in BotGreeting, where: g.greeted_at < ^before), :count, :id)
  end
end
