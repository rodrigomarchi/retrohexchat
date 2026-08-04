defmodule RetroHexChat.Chat.Schemas.InputHistory do
  @moduledoc """
  Ecto schema for persisted composer input history.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "input_histories" do
    field :entries, {:array, :string}, default: []
    field :recent_commands, {:array, :string}, default: []

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(history, attrs) do
    history
    |> cast(attrs, [:owner_nickname, :entries, :recent_commands])
    |> validate_required([:owner_nickname, :entries, :recent_commands])
    |> validate_length(:owner_nickname, max: 16)
  end
end
