defmodule RetroHexChat.Repo.Migrations.CreateSoloSessions do
  use Ecto.Migration

  def change do
    create table(:solo_sessions) do
      add :token, :string, size: 64, null: false
      add :creator_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :status, :string, size: 20, null: false, default: "pending"
      add :game_id, :string, size: 30
      add :metadata, :map, null: false, default: %{}
      add :closed_at, :utc_datetime_usec
      add :closed_reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:solo_sessions, [:token])
    create index(:solo_sessions, [:creator_id])
    create index(:solo_sessions, [:status])
    create index(:solo_sessions, [:creator_id, :status])
  end
end
