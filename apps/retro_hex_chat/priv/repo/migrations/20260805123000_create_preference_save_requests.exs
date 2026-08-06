defmodule RetroHexChat.Repo.Migrations.CreatePreferenceSaveRequests do
  use Ecto.Migration

  def change do
    create table(:preference_save_requests) do
      add :owner_nickname, :string, null: false, size: 16
      add :preference_type, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :payload_size_bytes, :integer, null: false, default: 0
      add :status, :string, null: false, default: "pending"
      add :revision, :integer, null: false, default: 1
      add :applied_revision, :integer, null: false, default: 0
      add :attempts, :integer, null: false, default: 0
      add :last_attempted_at, :utc_datetime_usec
      add :last_error, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:preference_save_requests, [:owner_nickname, :preference_type])
    create index(:preference_save_requests, [:status, :updated_at])
    create index(:preference_save_requests, [:preference_type, :status])

    create constraint(:preference_save_requests, :preference_save_requests_status_check,
             check: "status IN ('pending', 'processing', 'applied', 'failed')"
           )

    create constraint(
             :preference_save_requests,
             :preference_save_requests_payload_size_non_negative,
             check: "payload_size_bytes >= 0"
           )

    create constraint(:preference_save_requests, :preference_save_requests_revision_positive,
             check: "revision > 0"
           )

    create constraint(:preference_save_requests, :preference_save_requests_applied_revision_valid,
             check: "applied_revision >= 0 AND applied_revision <= revision"
           )

    create constraint(:preference_save_requests, :preference_save_requests_attempts_non_negative,
             check: "attempts >= 0"
           )
  end
end
