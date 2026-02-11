defmodule RetroHexChat.Presence.NotifyListEntry do
  @moduledoc """
  Ecto schema for notify_list_entries table.
  Persists buddy list entries for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "notify_list_entries" do
    field :owner_nickname, :string
    field :tracked_nickname, :string
    field :note, :string
    field :last_seen_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:owner_nickname, :tracked_nickname, :note, :last_seen_at])
    |> validate_required([:owner_nickname, :tracked_nickname])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:tracked_nickname, max: 16)
    |> validate_length(:note, max: 200)
  end
end
