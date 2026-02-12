defmodule RetroHexChat.Chat.Schemas.FavoriteEntry do
  @moduledoc """
  Ecto schema for favorites table.
  Persists per-user favorite channel entries for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "favorites" do
    field :owner_nickname, :string
    field :channel_name, :string
    field :description, :string
    field :encrypted_password, :string
    field :auto_join, :boolean
    field :position, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :owner_nickname,
      :channel_name,
      :description,
      :encrypted_password,
      :auto_join,
      :position
    ])
    |> validate_required([:owner_nickname, :channel_name, :position])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:channel_name, min: 2, max: 50)
    |> validate_length(:description, max: 200)
  end
end
