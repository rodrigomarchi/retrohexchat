defmodule RetroHexChat.Repo.Migrations.CreateScrapedPages do
  use Ecto.Migration

  def change do
    create table(:scraped_pages) do
      add :url, :text, null: false
      add :url_hash, :string, null: false, size: 64
      add :status, :string, null: false, default: "pending"

      add :title, :text
      add :description, :text
      add :image_url, :text
      add :site_name, :text
      add :canonical_url, :text
      add :author, :text
      add :published_at, :utc_datetime_usec
      add :lang, :string
      add :content_text, :text
      add :content_text_truncated, :boolean, null: false, default: false

      add :final_url, :text
      add :http_status, :integer
      add :content_type, :string
      add :etag, :string
      add :last_modified, :string
      add :scraper_version, :integer, null: false, default: 1
      add :raw_metadata, :map, null: false, default: %{}

      add :error_reason, :string
      add :error_detail, :map, null: false, default: %{}
      add :attempts, :integer, null: false, default: 0
      add :last_attempted_at, :utc_datetime_usec

      add :fetched_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec, null: false
      add :last_accessed_at, :utc_datetime_usec
      add :revalidating_since, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:scraped_pages, [:url_hash])
    create index(:scraped_pages, [:status])
    create index(:scraped_pages, [:expires_at])
    create index(:scraped_pages, [:status, :expires_at])
    create index(:scraped_pages, [:last_accessed_at])
    create index(:scraped_pages, [:scraper_version])

    create constraint(:scraped_pages, :scraped_pages_status_check,
             check: "status IN ('pending', 'ready', 'failed')"
           )

    create constraint(:scraped_pages, :scraped_pages_attempts_non_negative,
             check: "attempts >= 0"
           )
  end
end
