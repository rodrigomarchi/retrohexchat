defmodule RetroHexChat.Bots.BotEventLog do
  @moduledoc """
  Ecto schema for bot event logging (stats/debug).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Bots.Bot

  @type t :: %__MODULE__{}

  schema "bot_event_log" do
    belongs_to :bot, Bot
    field :event_type, :string
    field :channel, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:bot_id, :event_type, :channel, :metadata])
    |> validate_required([:bot_id, :event_type])
  end
end
