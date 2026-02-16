defmodule RetroHexChat.Repo.Migrations.CreateP2pSessions do
  use Ecto.Migration

  def change do
    create table(:p2p_sessions) do
      add :token, :string, size: 64, null: false
      add :creator_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :peer_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :status, :string, size: 20, null: false, default: "pending"
      add :session_type, :string, size: 20, null: false, default: "generic"
      add :metadata, :map, null: false, default: %{}
      add :closed_at, :utc_datetime_usec
      add :closed_reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:p2p_sessions, [:token])
    create index(:p2p_sessions, [:creator_id])
    create index(:p2p_sessions, [:peer_id])
    create index(:p2p_sessions, [:status])
    create index(:p2p_sessions, [:creator_id, :peer_id, :status])
  end
end
