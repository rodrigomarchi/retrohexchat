defmodule RetroHexChat.Chat.Schemas.UserBio do
  @moduledoc """
  Ecto schema for user_bios table.
  Persists per-user bio text for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @max_bio_length 200

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "user_bios" do
    field :bio_text, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(bio, attrs) do
    bio
    |> cast(attrs, [:owner_nickname, :bio_text])
    |> validate_required([:owner_nickname, :bio_text])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:bio_text, max: @max_bio_length)
  end
end
