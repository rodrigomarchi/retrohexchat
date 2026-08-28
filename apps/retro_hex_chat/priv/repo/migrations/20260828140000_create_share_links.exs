defmodule RetroHexChat.Repo.Migrations.CreateShareLinks do
  use Ecto.Migration

  def change do
    create table(:share_links) do
      add :slug, :string, size: 32, null: false
      add :kind, :string, size: 16, null: false
      add :target, :map, null: false, default: %{}
      add :creator_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :creator_nick, :string, size: 16, null: false
      add :expires_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      add :revoked_by, :string, size: 16
      add :resolve_count, :integer, null: false, default: 0
      add :last_resolved_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    # The slug is the only lookup key on the public route, so it is unique and
    # indexed for that one query.
    create unique_index(:share_links, [:slug])

    # Revocation is always "the links I made", never a scan.
    create index(:share_links, [:creator_id])
  end
end
