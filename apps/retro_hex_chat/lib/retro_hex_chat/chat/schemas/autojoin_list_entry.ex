defmodule RetroHexChat.Chat.Schemas.AutojoinListEntry do
  @moduledoc """
  Ecto schema for autojoin_entries table.
  Persists per-user auto-join channel list for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "autojoin_entries" do
    field :owner_nickname, :string
    field :channel_name, :string
    field :channel_key, :string
    field :position, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:owner_nickname, :channel_name, :channel_key, :position])
    |> validate_required([:owner_nickname, :channel_name, :position])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:channel_name, min: 2, max: 50)
    |> validate_length(:channel_key, max: 50)
  end
end
