defmodule RetroHexChat.Accounts.TrustedDevice do
  @moduledoc "Persisted browser/device token that can identify one or more registered nicks."
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "trusted_devices" do
    field :selector, :string
    field :token_hash, :string
    field :label, :string
    field :browser, :string
    field :os, :string
    field :device_type, :string
    field :language, :string
    field :timezone, :string
    field :screen, :string
    field :color_depth, :integer
    field :touch, :boolean, default: false
    field :cores, :integer
    field :user_agent_hash, :string
    field :last_ip_hash, :string
    field :first_seen_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :revoked_by_nickname, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :selector,
      :token_hash,
      :label,
      :browser,
      :os,
      :device_type,
      :language,
      :timezone,
      :screen,
      :color_depth,
      :touch,
      :cores,
      :user_agent_hash,
      :last_ip_hash,
      :first_seen_at,
      :last_seen_at,
      :expires_at,
      :revoked_at,
      :revoked_by_nickname
    ])
    |> validate_required([:selector, :token_hash, :first_seen_at, :last_seen_at, :expires_at])
    |> validate_length(:selector, max: 64)
    |> validate_length(:token_hash, max: 128)
    |> validate_length(:label, max: 100)
    |> validate_length(:browser, max: 100)
    |> validate_length(:os, max: 100)
    |> validate_length(:device_type, max: 32)
    |> validate_length(:language, max: 32)
    |> validate_length(:timezone, max: 100)
    |> validate_length(:screen, max: 32)
    |> validate_length(:user_agent_hash, max: 64)
    |> validate_length(:last_ip_hash, max: 64)
    |> validate_length(:revoked_by_nickname, max: 16)
    |> unique_constraint(:selector)
  end
end
