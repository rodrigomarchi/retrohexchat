defmodule RetroHexChat.Bots.BotCustomCommand do
  @moduledoc """
  Ecto schema for bot custom commands (!prefix trigger → response).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Bots.Bot

  @type t :: %__MODULE__{}

  schema "bot_custom_commands" do
    belongs_to :bot, Bot
    field :trigger, :string
    field :response, :string
    field :description, :string
    field :enabled, :boolean, default: true
    field :added_by, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(command, attrs) do
    command
    |> cast(attrs, [:bot_id, :trigger, :response, :description, :enabled, :added_by])
    |> validate_required([:bot_id, :trigger, :response, :added_by])
    |> validate_length(:trigger, min: 1, max: 32)
    |> validate_length(:response, min: 1, max: 500)
    |> validate_format(:trigger, ~r/^[a-zA-Z0-9_-]+$/, message: "only letters, numbers, _ and -")
    |> unique_constraint([:bot_id, :trigger], name: :bot_custom_commands_bot_id_trigger_index)
  end
end
