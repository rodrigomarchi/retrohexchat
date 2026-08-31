defmodule RetroHexChat.Repo.Migrations.OpenLobbySessions do
  use Ecto.Migration

  def up do
    alter table(:lobby_sessions) do
      modify :peer_id, :bigint, null: true
      add :expires_at, :utc_datetime_usec
    end

    # The sweep's access path, and the only one this table did not already
    # have: find the open lobbies whose window has closed. The conditional
    # claim needs no index of its own — `token` is already unique, and a
    # second index on the same column would never be chosen.
    create index(:lobby_sessions, [:expires_at],
             where: "peer_id IS NULL AND status = 'open'",
             name: :idx_lobby_sessions_open_expiry
           )
  end

  def down do
    drop index(:lobby_sessions, [:expires_at], name: :idx_lobby_sessions_open_expiry)

    execute "DELETE FROM lobby_sessions WHERE peer_id IS NULL"

    alter table(:lobby_sessions) do
      modify :peer_id, :bigint, null: false
      remove :expires_at
    end
  end
end
