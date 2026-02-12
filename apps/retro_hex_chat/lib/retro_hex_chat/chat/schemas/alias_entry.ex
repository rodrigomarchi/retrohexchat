defmodule RetroHexChat.Chat.Schemas.AliasEntry do
  @moduledoc """
  Ecto schema for aliases table.
  Persists per-user alias entries for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "aliases" do
    field :owner_nickname, :string
    field :name, :string
    field :expansion, :string
    field :position, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:owner_nickname, :name, :expansion, :position])
    |> validate_required([:owner_nickname, :name, :expansion, :position])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:name, min: 1, max: 30)
    |> validate_length(:expansion, min: 1, max: 500)
  end
end
