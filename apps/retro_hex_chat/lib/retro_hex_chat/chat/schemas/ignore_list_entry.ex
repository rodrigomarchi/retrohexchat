defmodule RetroHexChat.Chat.Schemas.IgnoreListEntry do
  @moduledoc """
  Ecto schema for ignore_list_entries table.
  Persists per-user ignore list entries for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @valid_types ~w(all messages pms invites actions)

  schema "ignore_list_entries" do
    field :owner_nickname, :string
    field :ignored_nickname, :string
    field :ignore_type, :string
    field :expires_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:owner_nickname, :ignored_nickname, :ignore_type, :expires_at])
    |> validate_required([:owner_nickname, :ignored_nickname, :ignore_type])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:ignored_nickname, max: 16)
    |> validate_inclusion(:ignore_type, @valid_types)
  end
end
