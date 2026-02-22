defmodule RetroHexChat.Admin.ServerBan do
  @moduledoc "Ecto schema for server-level bans."
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "server_bans" do
    field :nickname, :string
    field :reason, :string
    field :banned_by, :string
    field :expires_at, :utc_datetime_usec
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(ban, attrs) do
    ban
    |> cast(attrs, [:nickname, :reason, :banned_by, :expires_at, :active])
    |> validate_required([:nickname, :banned_by])
    |> validate_length(:nickname, max: 16)
    |> validate_length(:banned_by, max: 16)
    |> unique_constraint(:nickname, name: :idx_server_bans_active_nickname)
  end
end
