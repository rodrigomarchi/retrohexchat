defmodule RetroHexChat.Chat.Schemas.AutoRespondRule do
  @moduledoc """
  Ecto schema for autorespond_rules table.
  Persists per-user auto-respond rules for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "autorespond_rules" do
    field :owner_nickname, :string
    field :trigger_event, :string
    field :channel_filter, :string
    field :command, :string
    field :enabled, :boolean, default: true
    field :position, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :owner_nickname,
      :trigger_event,
      :channel_filter,
      :command,
      :enabled,
      :position
    ])
    |> validate_required([:owner_nickname, :trigger_event, :command, :position])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_inclusion(:trigger_event, ["on_join", "on_part", "on_nick_change"])
    |> validate_length(:channel_filter, max: 50)
    |> validate_length(:command, min: 1, max: 500)
  end
end
