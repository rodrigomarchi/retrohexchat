defmodule RetroHexChat.Repo.Migrations.DropLinkPreviews do
  use Ecto.Migration

  # Superseded by `scraped_pages`, which every consumer now reads. Nothing is
  # carried over: the rows here expired an hour after they were written, so the
  # table held at most an hour of titles, and the new normalisation hashes URLs
  # differently anyway.
  def up do
    drop table(:link_previews)
  end

  def down do
    create table(:link_previews) do
      add :url, :text, null: false
      add :url_hash, :string, null: false, size: 64
      add :status, :string, null: false, default: "pending"
      add :title, :string
      add :metadata, :map, null: false, default: %{}
      add :error_reason, :string
      add :error_detail, :map, null: false, default: %{}
      add :attempts, :integer, null: false, default: 0
      add :last_attempted_at, :utc_datetime_usec
      add :fetched_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:link_previews, [:url_hash])
    create index(:link_previews, [:status])
    create index(:link_previews, [:expires_at])
    create index(:link_previews, [:status, :expires_at])

    create constraint(:link_previews, :link_previews_status_check,
             check: "status IN ('pending', 'ready', 'failed')"
           )

    create constraint(:link_previews, :link_previews_attempts_non_negative,
             check: "attempts >= 0"
           )
  end
end
