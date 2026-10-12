defmodule RetroHexChat.VirtualSpace.Schema.Construct do
  @moduledoc """
  What was built in one Construct, as one row per room.

  The whole layout is the row: `items` is every placed piece, `floor` the
  painted floor (one character per tile, row by row, `.` where it is
  unpainted; `nil` for a floor nobody has painted) and `revision` counts the
  edits that produced it. Writing the room whole, guarded by the
  revision, is what keeps two people editing at once from undoing each other —
  a move landing after a removal can only ever bring back the newer room, never
  resurrect the removed chair.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "virtual_space_constructs" do
    field :space_id, :string
    field :items, {:array, :map}, default: []
    field :floor, :string
    field :revision, :integer, default: 0
    field :updated_by_nick, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(construct, attrs) do
    construct
    |> cast(attrs, [:space_id, :items, :floor, :revision, :updated_by_nick])
    |> validate_required([:space_id, :revision])
    |> validate_length(:space_id, max: 120)
    |> validate_length(:floor, max: 16_384)
    |> validate_number(:revision, greater_than_or_equal_to: 0)
    |> update_change(:updated_by_nick, &truncate_nick/1)
    |> unique_constraint(:space_id)
  end

  defp truncate_nick(nick) when is_binary(nick), do: String.slice(nick, 0, 16)
  defp truncate_nick(nick), do: nick
end
