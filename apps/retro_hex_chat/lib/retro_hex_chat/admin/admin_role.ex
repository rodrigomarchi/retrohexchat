defmodule RetroHexChat.Admin.AdminRole do
  @moduledoc "Ecto schema for database-managed admin/server_operator roles."
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @valid_roles ~w(admin server_operator)

  schema "admin_roles" do
    field :nickname, :string
    field :role, :string
    field :granted_by, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:nickname, :role, :granted_by])
    |> validate_required([:nickname, :role, :granted_by])
    |> validate_length(:nickname, max: 16)
    |> validate_length(:granted_by, max: 16)
    |> validate_inclusion(:role, @valid_roles)
    |> unique_constraint([:nickname, :role])
  end
end
