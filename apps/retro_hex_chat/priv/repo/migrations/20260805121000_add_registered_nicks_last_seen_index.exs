defmodule RetroHexChat.Repo.Migrations.AddRegisteredNicksLastSeenIndex do
  use Ecto.Migration

  def change do
    create index(:registered_nicks, [:last_seen_at], name: :idx_registered_nicks_last_seen_at)
  end
end
