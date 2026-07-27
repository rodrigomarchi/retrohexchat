defmodule RetroHexChat.Accounts.TrustedDeviceNick do
  @moduledoc "Join table authorizing a trusted device to identify a registered nick."
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Accounts.TrustedDevice
  alias RetroHexChat.Services.RegisteredNick

  @type t :: %__MODULE__{}

  schema "trusted_device_nicks" do
    belongs_to :trusted_device, TrustedDevice
    belongs_to :registered_nick, RegisteredNick
    field :granted_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :revoked_by_nickname, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [
      :trusted_device_id,
      :registered_nick_id,
      :granted_at,
      :last_used_at,
      :revoked_at,
      :revoked_by_nickname
    ])
    |> validate_required([:trusted_device_id, :registered_nick_id, :granted_at])
    |> validate_length(:revoked_by_nickname, max: 16)
    |> foreign_key_constraint(:trusted_device_id)
    |> foreign_key_constraint(:registered_nick_id)
    |> unique_constraint([:trusted_device_id, :registered_nick_id],
      name: :trusted_device_nicks_device_nick_unique
    )
  end
end
