defmodule RetroHexChat.Repo.Migrations.BackfillLastSeenAt do
  use Ecto.Migration

  def up do
    execute "UPDATE registered_nicks SET last_seen_at = registered_at WHERE last_seen_at IS NULL"
  end

  def down do
    :ok
  end
end
