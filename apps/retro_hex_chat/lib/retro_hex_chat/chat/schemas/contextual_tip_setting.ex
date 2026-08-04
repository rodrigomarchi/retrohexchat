defmodule RetroHexChat.Chat.Schemas.ContextualTipSetting do
  @moduledoc """
  Ecto schema for persisted contextual tip state.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "contextual_tip_settings" do
    field :seen_tips, {:array, :string}, default: []
    field :suppressed, :boolean, default: false

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:owner_nickname, :seen_tips, :suppressed])
    |> validate_required([:owner_nickname, :seen_tips, :suppressed])
    |> validate_length(:owner_nickname, max: 16)
  end
end
