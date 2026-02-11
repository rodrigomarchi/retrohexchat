defmodule RetroHexChat.Accounts.HighlightWordEntry do
  @moduledoc """
  Ecto schema for highlight_words table.
  Persists per-user highlight words for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "highlight_words" do
    field :owner_nickname, :string
    field :word, :string
    field :bg_color, :integer
    field :position, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:owner_nickname, :word, :bg_color, :position])
    |> validate_required([:owner_nickname, :word, :position])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:word, max: 50)
    |> validate_inclusion(:bg_color, 0..15)
  end
end
