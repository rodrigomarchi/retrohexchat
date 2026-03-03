defmodule RetroHexChat.Bots.Queries do
  @moduledoc """
  CRUD operations for bot persistence.
  """

  import Ecto.Query

  alias RetroHexChat.Bots.{Bot, BotChannelConfig, BotCustomCommand, BotEventLog}
  alias RetroHexChat.Repo

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

  @spec list_bots() :: [Bot.t()]
  def list_bots do
    Bot |> order_by(:name) |> Repo.all()
  end

  @spec list_bots_by_creator(String.t()) :: [Bot.t()]
  def list_bots_by_creator(nickname) do
    Bot |> where(created_by: ^nickname) |> order_by(:name) |> Repo.all()
  end

  @spec list_enabled_bots() :: [Bot.t()]
  def list_enabled_bots do
    Bot
    |> where(enabled: true)
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

  @spec list_channel_configs(integer()) :: [BotChannelConfig.t()]
  def list_channel_configs(bot_id) do
    BotChannelConfig
    |> where(bot_id: ^bot_id)
    |> order_by(:channel_name)
    |> Repo.all()
  end

  @spec update_channel_config(BotChannelConfig.t(), map()) ::
          {:ok, BotChannelConfig.t()} | {:error, Ecto.Changeset.t()}
  def update_channel_config(%BotChannelConfig{} = config, attrs) do
    config
    |> BotChannelConfig.changeset(attrs)
    |> Repo.update()
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

  @spec list_custom_commands(integer()) :: [BotCustomCommand.t()]
  def list_custom_commands(bot_id) do
    BotCustomCommand
    |> where(bot_id: ^bot_id)
    |> order_by(:trigger)
    |> Repo.all()
  end

  # ── Event Log ─────────────────────────────────────────────────

  @spec list_event_logs(integer(), keyword()) :: [BotEventLog.t()]
  def list_event_logs(bot_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    BotEventLog
    |> where(bot_id: ^bot_id)
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

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
end
