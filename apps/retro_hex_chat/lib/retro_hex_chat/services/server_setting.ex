defmodule RetroHexChat.Services.ServerSetting do
  @moduledoc "Ecto schema for server_settings key-value table."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          key: String.t() | nil,
          value: String.t() | nil,
          updated_by: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "server_settings" do
    field :key, :string
    field :value, :string
    field :updated_by, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value, :updated_by])
    |> validate_required([:key])
    |> validate_length(:key, max: 50)
    |> validate_length(:updated_by, max: 16)
    |> unique_constraint(:key, name: :idx_server_settings_key)
  end
end
