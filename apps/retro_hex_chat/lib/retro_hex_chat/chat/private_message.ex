defmodule RetroHexChat.Chat.PrivateMessage do
  @moduledoc """
  Ecto schema for private messages between two users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @type_values ~w(message action)

  schema "private_messages" do
    field :sender_nickname, :string
    field :recipient_nickname, :string
    field :content, :string
    field :type, :string, default: "message"

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(pm, attrs) do
    pm
    |> cast(attrs, [:sender_nickname, :recipient_nickname, :content, :type])
    |> validate_required([:sender_nickname, :recipient_nickname, :content])
    |> validate_length(:sender_nickname, max: 16)
    |> validate_length(:recipient_nickname, max: 16)
    |> validate_inclusion(:type, @type_values)
  end
end
