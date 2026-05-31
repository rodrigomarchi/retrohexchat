defmodule RetroHexChat.Bots.Bot do
  @moduledoc """
  Ecto schema for bot configuration and persistence.
  """
  use Gettext, backend: RetroHexChat.Gettext
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Bots.{BotChannelConfig, BotCustomCommand}

  @type t :: %__MODULE__{}

  schema "bots" do
    field :name, :string
    field :nickname, :string
    field :description, :string
    field :command_prefix, :string, default: "!"
    field :created_by, :string
    field :enabled, :boolean, default: true
    field :cooldown_ms, :integer, default: 2000
    field :capabilities, :map, default: %{}
    field :stats, :map, default: %{"messages_handled" => 0, "commands_processed" => 0}

    has_many :channel_configs, BotChannelConfig
    has_many :custom_commands, BotCustomCommand

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:name, :nickname, :created_by]
  @optional_fields [:description, :command_prefix, :enabled, :cooldown_ms, :capabilities, :stats]

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(bot, attrs) do
    bot
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 2, max: 16)
    |> validate_length(:nickname, min: 2, max: 16)
    |> validate_length(:command_prefix, min: 1, max: 3)
    |> validate_number(:cooldown_ms, greater_than_or_equal_to: 500)
    |> validate_format(:name, ~r/^[a-zA-Z0-9_-]+$/,
      message: gettext("only letters, numbers, _ and -")
    )
    |> validate_format(:nickname, ~r/^[a-zA-Z][a-zA-Z0-9_-]*$/,
      message: gettext("must start with a letter")
    )
    |> unique_constraint(:name, name: :bots_name_index)
    |> unique_constraint(:nickname, name: :bots_nickname_index)
  end

  @spec update_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(bot, attrs) do
    bot
    |> cast(attrs, @optional_fields)
    |> validate_length(:command_prefix, min: 1, max: 3)
    |> validate_number(:cooldown_ms, greater_than_or_equal_to: 500)
  end
end
