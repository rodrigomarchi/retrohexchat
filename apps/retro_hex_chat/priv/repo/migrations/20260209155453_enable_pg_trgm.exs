defmodule RetroHexChat.Repo.Migrations.EnablePgTrgm do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm"

    # GIN trigram indexes for text search
    execute(
      "CREATE INDEX idx_messages_content_trgm ON messages USING gin (content gin_trgm_ops)",
      "DROP INDEX idx_messages_content_trgm"
    )

    execute(
      "CREATE INDEX idx_pm_content_trgm ON private_messages USING gin (content gin_trgm_ops)",
      "DROP INDEX idx_pm_content_trgm"
    )
  end
end
