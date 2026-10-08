defmodule RetroHexChat.Repo.Migrations.DropMessagesContentTrgmIndex do
  use Ecto.Migration

  # `Chat.Search` matches `coalesce(plain_content, content) ILIKE ?`. A GIN index
  # on `content` alone cannot answer an expression over two columns, so the
  # planner never chose it: production recorded zero scans of it while it held
  # 1.5 GB and taxed every message insert with a trigram update.
  #
  # Search keeps the plan it already had. An index that served it would have to
  # be built on the same `coalesce(...)` expression the query uses.
  #
  # Dropped concurrently: `messages` is the busiest table on the server and a
  # plain DROP INDEX takes an exclusive lock on it.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_messages_content_trgm"
  end

  def down do
    execute "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_content_trgm ON messages USING gin (content gin_trgm_ops)"
  end
end
