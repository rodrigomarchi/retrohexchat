defmodule RetroHexChat.Admin.AuditLog do
  @moduledoc "Ecto schema for the append-only admin audit log."
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "audit_logs" do
    field :actor, :string
    field :action, :string
    field :target_type, :string
    field :target_id, :string
    field :details, :map, default: %{}
    field :inserted_at, :utc_datetime_usec
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:actor, :action, :target_type, :target_id, :details])
    |> validate_required([:actor, :action])
    |> validate_length(:actor, max: 16)
    |> validate_length(:action, max: 64)
    |> validate_length(:target_type, max: 32)
    |> validate_length(:target_id, max: 64)
    |> put_inserted_at()
  end

  defp put_inserted_at(%Ecto.Changeset{valid?: true} = changeset) do
    put_change(changeset, :inserted_at, DateTime.utc_now())
  end

  defp put_inserted_at(changeset), do: changeset
end
