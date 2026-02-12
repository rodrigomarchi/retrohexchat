defmodule RetroHexChat.Chat.Schemas.SoundSetting do
  @moduledoc """
  Ecto schema for sound_settings table.
  Persists per-user sound and flash preferences for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "sound_settings" do
    field :sound_mappings, :map, default: %{}
    field :flash_settings, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:owner_nickname, :sound_mappings, :flash_settings])
    |> validate_required([:owner_nickname])
    |> validate_length(:owner_nickname, max: 16)
  end
end
