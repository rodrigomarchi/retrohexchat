defmodule RetroHexChat.Chat.Schemas.PerformSettings do
  @moduledoc """
  Ecto schema for perform_settings table.
  Persists per-user perform settings (enable/disable toggle) for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "perform_settings" do
    field :enable_on_connect, :boolean, default: true

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:owner_nickname, :enable_on_connect])
    |> validate_required([:owner_nickname, :enable_on_connect])
    |> validate_length(:owner_nickname, max: 16)
  end
end
