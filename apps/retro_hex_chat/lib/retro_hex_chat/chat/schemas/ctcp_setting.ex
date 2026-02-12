defmodule RetroHexChat.Chat.Schemas.CtcpSetting do
  @moduledoc """
  Ecto schema for ctcp_settings table.
  Persists per-user CTCP reply configuration for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @max_string_length 200

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "ctcp_settings" do
    field :enabled, :boolean, default: true
    field :version_string, :string, default: "RetroHexChat v1.0"
    field :finger_text, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:owner_nickname, :enabled, :version_string, :finger_text])
    |> validate_required([:owner_nickname, :enabled, :version_string])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:version_string, max: @max_string_length)
    |> validate_length(:finger_text, max: @max_string_length)
  end
end
