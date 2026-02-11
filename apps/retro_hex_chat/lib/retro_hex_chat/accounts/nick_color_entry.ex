defmodule RetroHexChat.Accounts.NickColorEntry do
  @moduledoc """
  Ecto schema for nick_color_overrides table.
  Persists per-user nickname color overrides for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "nick_color_overrides" do
    field :owner_nickname, :string
    field :target_nickname, :string
    field :color_index, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:owner_nickname, :target_nickname, :color_index])
    |> validate_required([:owner_nickname, :target_nickname, :color_index])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:target_nickname, max: 16)
    |> validate_inclusion(:color_index, 0..15)
  end
end
