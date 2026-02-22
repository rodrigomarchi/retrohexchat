defmodule RetroHexChat.Bots.BotChannelConfig do
  @moduledoc """
  Ecto schema for per-channel bot configuration.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Bots.Bot

  @type t :: %__MODULE__{}

  schema "bot_channel_configs" do
    belongs_to :bot, Bot
    field :channel_name, :string
    field :enabled, :boolean, default: true
    field :capability_overrides, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:bot_id, :channel_name, :enabled, :capability_overrides])
    |> validate_required([:bot_id, :channel_name])
    |> validate_length(:channel_name, min: 2, max: 50)
    |> unique_constraint([:bot_id, :channel_name],
      name: :bot_channel_configs_bot_id_channel_name_index
    )
  end
end
