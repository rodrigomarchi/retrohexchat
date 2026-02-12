defmodule RetroHexChat.Chat.Schemas.CustomMenuItem do
  @moduledoc """
  Ecto schema for custom_menu_items table.
  Persists per-user custom context menu items for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "custom_menu_items" do
    field :owner_nickname, :string
    field :menu_type, :string
    field :label, :string
    field :command, :string
    field :position, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:owner_nickname, :menu_type, :label, :command, :position])
    |> validate_required([:owner_nickname, :menu_type, :label, :command, :position])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_inclusion(:menu_type, ["nicklist", "channel"])
    |> validate_length(:label, min: 1, max: 50)
    |> validate_length(:command, min: 1, max: 500)
  end
end
