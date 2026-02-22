defmodule RetroHexChat.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :actor, :string, size: 16, null: false
      add :action, :string, size: 64, null: false
      add :target_type, :string, size: 32
      add :target_id, :string, size: 64
      add :details, :map, default: %{}

      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:audit_logs, [:actor])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:inserted_at])
    create index(:audit_logs, [:target_type, :target_id])
  end
end
