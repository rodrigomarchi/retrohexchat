defmodule RetroHexChat.Services.InviteException do
  @moduledoc """
  Ecto schema for persisted invite exceptions (+I) on registered channels.
  An invite exception allows a user to bypass invite-only mode (+i) without
  needing an explicit invite.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "invite_exceptions" do
    field :channel_name, :string
    field :nickname, :string
    field :added_by, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(exception, attrs) do
    exception
    |> cast(attrs, [:channel_name, :nickname, :added_by])
    |> validate_required([:channel_name, :nickname, :added_by])
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:nickname, max: 16)
    |> validate_length(:added_by, max: 16)
    |> unique_constraint([:channel_name, :nickname],
      name: :idx_invite_exceptions_channel_nickname
    )
  end
end
