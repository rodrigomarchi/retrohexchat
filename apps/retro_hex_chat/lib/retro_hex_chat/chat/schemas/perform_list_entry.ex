defmodule RetroHexChat.Chat.Schemas.PerformListEntry do
  @moduledoc """
  Ecto schema for perform_entries table.
  Persists per-user perform list entries for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "perform_entries" do
    field :owner_nickname, :string
    field :command, :string
    field :position, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:owner_nickname, :command, :position])
    |> validate_required([:owner_nickname, :command, :position])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:command, min: 1, max: 500)
  end
end
