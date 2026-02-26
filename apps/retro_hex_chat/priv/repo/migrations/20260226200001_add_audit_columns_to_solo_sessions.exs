defmodule RetroHexChat.Repo.Migrations.AddAuditColumnsToSoloSessions do
  use Ecto.Migration

  def change do
    alter table(:solo_sessions) do
      add :lobby_at, :utc_datetime_usec
      add :game_started_at, :utc_datetime_usec
      add :duration_seconds, :integer
    end

    create index(:solo_sessions, [:game_id])
    create index(:solo_sessions, [:game_started_at])
  end
end
