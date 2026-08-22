defmodule RetroHexChat.Chat.Schemas.ReconnectState do
  @moduledoc """
  Ecto schema for persisted chat reconnect snapshots.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "reconnect_states" do
    field :channels, {:array, :string}, default: []
    field :active_channel, :string
    field :active_pm, :string
    field :open_pm_tabs, {:array, :string}, default: []
    field :welcomed_channels, {:array, :string}, default: []

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(reconnect_state, attrs) do
    reconnect_state
    |> cast(attrs, [
      :owner_nickname,
      :channels,
      :active_channel,
      :active_pm,
      :open_pm_tabs,
      :welcomed_channels
    ])
    |> validate_required([
      :owner_nickname,
      :channels,
      :open_pm_tabs,
      :welcomed_channels
    ])
    |> validate_length(:owner_nickname, max: 16)
  end
end
