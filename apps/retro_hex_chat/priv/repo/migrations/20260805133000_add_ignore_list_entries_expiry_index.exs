defmodule RetroHexChat.Repo.Migrations.AddIgnoreListEntriesExpiryIndex do
  use Ecto.Migration

  def change do
    create index(:ignore_list_entries, [:expires_at],
             name: :idx_ignore_list_entries_expires_at,
             where: "expires_at IS NOT NULL"
           )
  end
end
