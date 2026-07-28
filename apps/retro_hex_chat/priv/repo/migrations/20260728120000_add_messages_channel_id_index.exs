defmodule RetroHexChat.Repo.Migrations.AddMessagesChannelIdIndex do
  use Ecto.Migration

  # The scrollback pages by keyset: `WHERE channel_name = ? AND id < ? ORDER BY
  # id DESC LIMIT n`. The only index that covered `channel_name` was ordered by
  # `inserted_at`, so Postgres read **every** row of the channel and then sorted
  # it to hand back one page — measured at 439 rows scanned to return 51 on a
  # 500-row channel, and that scan grows with the channel, not with the page.
  #
  # With this index the same query is an index scan of exactly the rows it
  # returns. Keyset pagination without an index on its own key is slower than
  # the offset it replaced, which is the trap the plan warned about.
  #
  # Built concurrently: `messages` is the busiest table on the server and a
  # plain CREATE INDEX would hold a write lock over the whole build.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:messages, [:channel_name, :id], concurrently: true)
  end
end
