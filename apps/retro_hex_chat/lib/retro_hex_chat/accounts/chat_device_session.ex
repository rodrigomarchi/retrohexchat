defmodule RetroHexChat.Accounts.ChatDeviceSession do
  @moduledoc "Audit row for an active or completed chat session on a trusted or guest device."
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Accounts.TrustedDevice
  alias RetroHexChat.Services.RegisteredNick

  @type t :: %__MODULE__{}

  schema "chat_device_sessions" do
    field :session_ref, :string
    belongs_to :trusted_device, TrustedDevice
    belongs_to :registered_nick, RegisteredNick
    field :nickname, :string
    field :client_info, :map, default: %{}
    field :connected_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :disconnected_at, :utc_datetime_usec
    field :disconnect_reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_ref,
      :trusted_device_id,
      :registered_nick_id,
      :nickname,
      :client_info,
      :connected_at,
      :last_seen_at,
      :disconnected_at,
      :disconnect_reason
    ])
    |> validate_required([:session_ref, :nickname, :client_info, :connected_at, :last_seen_at])
    |> validate_length(:session_ref, max: 64)
    |> validate_length(:nickname, max: 16)
    |> validate_length(:disconnect_reason, max: 100)
    |> unique_constraint(:session_ref)
    |> foreign_key_constraint(:trusted_device_id)
    |> foreign_key_constraint(:registered_nick_id)
  end
end
