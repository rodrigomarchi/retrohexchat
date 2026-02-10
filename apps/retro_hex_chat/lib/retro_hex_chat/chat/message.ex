defmodule RetroHexChat.Chat.Message do
  @moduledoc """
  Ecto schema for channel messages.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @type_values ~w(message action system service error)

  schema "messages" do
    field :channel_name, :string
    field :author_nickname, :string
    field :content, :string
    field :type, :string, default: "message"

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:channel_name, :author_nickname, :content, :type])
    |> validate_required([:channel_name, :author_nickname, :content])
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:author_nickname, max: 16)
    |> validate_inclusion(:type, @type_values)
  end
end
