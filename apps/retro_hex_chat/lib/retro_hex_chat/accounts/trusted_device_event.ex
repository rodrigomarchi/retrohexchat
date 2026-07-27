defmodule RetroHexChat.Accounts.TrustedDeviceEvent do
  @moduledoc "Append-only security event for trusted-device activity."
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Accounts.TrustedDevice
  alias RetroHexChat.Services.RegisteredNick

  @type t :: %__MODULE__{}

  schema "trusted_device_events" do
    belongs_to :trusted_device, TrustedDevice
    belongs_to :registered_nick, RegisteredNick
    field :actor_nickname, :string
    field :action, :string
    field :details, :map, default: %{}
    field :inserted_at, :utc_datetime_usec
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :trusted_device_id,
      :registered_nick_id,
      :actor_nickname,
      :action,
      :details,
      :inserted_at
    ])
    |> validate_required([:action, :details, :inserted_at])
    |> validate_length(:actor_nickname, max: 16)
    |> validate_length(:action, max: 64)
    |> foreign_key_constraint(:trusted_device_id)
    |> foreign_key_constraint(:registered_nick_id)
  end
end
