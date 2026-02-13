defmodule RetroHexChat.Chat.Schemas.UserPreference do
  @moduledoc """
  Ecto schema for user_preferences table.
  Persists per-user centralized preferences for registered users.
  Six JSONB columns store display, font, color, connect, message, and key binding settings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "user_preferences" do
    field :display_settings, :map, default: %{}
    field :font_settings, :map, default: %{}
    field :color_settings, :map, default: %{}
    field :connect_settings, :map, default: %{}
    field :message_settings, :map, default: %{}
    field :key_bindings, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :owner_nickname,
      :display_settings,
      :font_settings,
      :color_settings,
      :connect_settings,
      :message_settings,
      :key_bindings
    ])
    |> validate_required([:owner_nickname])
    |> validate_length(:owner_nickname, max: 16)
  end
end
