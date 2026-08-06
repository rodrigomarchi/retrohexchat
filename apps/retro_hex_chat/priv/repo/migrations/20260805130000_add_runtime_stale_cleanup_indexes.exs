defmodule RetroHexChat.Repo.Migrations.AddRuntimeStaleCleanupIndexes do
  use Ecto.Migration

  def change do
    create index(:lobby_sessions, [:updated_at],
             where: "status NOT IN ('closed', 'expired', 'failed')",
             name: :idx_lobby_sessions_stale_cleanup
           )

    create index(:solo_sessions, [:updated_at],
             where: "status NOT IN ('finished', 'closed', 'expired')",
             name: :idx_solo_sessions_stale_cleanup
           )

    create index(:group_call_rooms, [:updated_at],
             where: "status NOT IN ('closed', 'expired', 'failed')",
             name: :idx_group_call_rooms_stale_cleanup
           )
  end
end
