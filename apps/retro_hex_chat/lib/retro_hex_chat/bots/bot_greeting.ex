defmodule RetroHexChat.Bots.BotGreeting do
  @moduledoc """
  Ecto schema for the record of who a bot has already welcomed.

  Channel and nickname are stored folded to lower case. Nothing reads this table
  for display — it exists to answer one question on the join path, and folding it
  on the way in is what makes `Rodrigo` and `rodrigo` one person instead of two
  welcomes.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Bots.Bot

  @type t :: %__MODULE__{}

  schema "bot_greetings" do
    belongs_to :bot, Bot
    field :channel_name, :string
    field :nickname, :string
    field :greeted_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(greeting, attrs) do
    greeting
    |> cast(attrs, [:bot_id, :channel_name, :nickname, :greeted_at])
    |> validate_required([:bot_id, :channel_name, :nickname, :greeted_at])
    |> unique_constraint([:bot_id, :channel_name, :nickname],
      name: :idx_bot_greetings_recipient
    )
  end
end
