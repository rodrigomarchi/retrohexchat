defmodule RetroHexChat.Services.ChannelWelcomeMessage do
  @moduledoc "Ecto schema for channel_welcome_messages table."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          channel_name: String.t() | nil,
          message: String.t() | nil,
          set_by: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "channel_welcome_messages" do
    field :channel_name, :string
    field :message, :string
    field :set_by, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(welcome, attrs) do
    welcome
    |> cast(attrs, [:channel_name, :message, :set_by])
    |> validate_required([:channel_name, :message, :set_by])
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:set_by, max: 16)
    |> unique_constraint(:channel_name, name: :idx_channel_welcome_messages_channel_name)
  end
end
