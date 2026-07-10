defmodule RetroHexChat.Repo.Migrations.DropP2pSessions do
  use Ecto.Migration

  # The server-side P2P session lifecycle was removed — P2P is now a browser
  # peer-to-peer connection with no persisted session record. The legacy
  # `p2p_sessions` table (and its `P2P.Schema.Session`) is dead; drop it.

  def up do
    drop_if_exists table(:p2p_sessions)
  end

  def down do
    create table(:p2p_sessions) do
      add :token, :string, size: 64, null: false
      add :creator_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :peer_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :status, :string, size: 20, null: false, default: "pending"
      add :session_type, :string, size: 20, null: false, default: "generic"
      add :metadata, :map, null: false, default: %{}
      add :closed_at, :utc_datetime_usec
      add :closed_reason, :string, size: 100
      add :accepted_at, :utc_datetime_usec
      add :connected_at, :utc_datetime_usec
      add :duration_seconds, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:p2p_sessions, [:token])
    create index(:p2p_sessions, [:creator_id])
    create index(:p2p_sessions, [:peer_id])
    create index(:p2p_sessions, [:status])
    create index(:p2p_sessions, [:creator_id, :peer_id, :status])
    create index(:p2p_sessions, [:accepted_at])
    create index(:p2p_sessions, [:connected_at])
  end
end
