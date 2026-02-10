defmodule RetroHexChat.Services.AccessListEntry do
  @moduledoc """
  Ecto schema for ChanServ access list entries.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @level_values ~w(founder sop aop vop)

  schema "access_list_entries" do
    field :channel_name, :string
    field :nickname, :string
    field :level, :string
    field :added_by, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:channel_name, :nickname, :level, :added_by])
    |> validate_required([:channel_name, :nickname, :level, :added_by])
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:nickname, max: 16)
    |> validate_length(:added_by, max: 16)
    |> validate_inclusion(:level, @level_values)
    |> unique_constraint([:channel_name, :nickname], name: :idx_access_list_channel_nickname)
  end
end
