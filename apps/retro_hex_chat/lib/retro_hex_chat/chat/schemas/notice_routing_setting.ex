defmodule RetroHexChat.Chat.Schemas.NoticeRoutingSetting do
  @moduledoc """
  Ecto schema for notice_routing_settings table.
  Persists per-user notice routing preference for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @valid_routings ["active", "status", "sender"]

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "notice_routing_settings" do
    field :routing, :string, default: "active"

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:owner_nickname, :routing])
    |> validate_required([:owner_nickname, :routing])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_inclusion(:routing, @valid_routings)
  end
end
