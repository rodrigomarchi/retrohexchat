defmodule RetroHexChat.Services.Ban do
  @moduledoc """
  Ecto schema for persisted bans on registered channels.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "bans" do
    field :channel_name, :string
    field :banned_nickname, :string
    field :banned_by, :string
    field :reason, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(ban, attrs) do
    ban
    |> cast(attrs, [:channel_name, :banned_nickname, :banned_by, :reason])
    |> validate_required([:channel_name, :banned_nickname, :banned_by])
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:banned_nickname, max: 16)
    |> validate_length(:banned_by, max: 16)
    |> validate_length(:reason, max: 255)
    |> unique_constraint([:channel_name, :banned_nickname], name: :idx_bans_channel_nickname)
  end
end
