defmodule RetroHexChat.Games.Schema.GameRating do
  @moduledoc """
  One player's standing in one Retro Game against other people: an Elo rating
  and the record it came from. Every mode of a game shares the game's rating.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "game_ratings" do
    field :base_id, :string
    field :player_id, :integer
    field :rating, :integer
    field :matches, :integer, default: 0
    field :wins, :integer, default: 0
    field :losses, :integer, default: 0
    field :draws, :integer, default: 0

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(rating, attrs) do
    rating
    |> cast(attrs, [:base_id, :player_id, :rating, :matches, :wins, :losses, :draws])
    |> validate_required([:base_id, :player_id, :rating])
    |> unique_constraint([:base_id, :player_id])
  end
end
