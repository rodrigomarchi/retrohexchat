defmodule RetroHexChat.Repo.Migrations.AddAuditColumnsToSessions do
  use Ecto.Migration

  def change do
    alter table(:p2p_sessions) do
      add :accepted_at, :utc_datetime_usec
      add :connected_at, :utc_datetime_usec
      add :duration_seconds, :integer
    end

    alter table(:game_sessions) do
      add :lobby_at, :utc_datetime_usec
      add :game_started_at, :utc_datetime_usec
      add :duration_seconds, :integer
    end

    create index(:p2p_sessions, [:accepted_at])
    create index(:p2p_sessions, [:connected_at])
    create index(:game_sessions, [:lobby_at])
    create index(:game_sessions, [:game_started_at])
  end
end
