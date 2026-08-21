defmodule RetroHexChat.Repo.Migrations.AddImageThumbnailsToScrapedPages do
  use Ecto.Migration

  def change do
    alter table(:scraped_pages) do
      add :image_thumbnail_status, :string, null: false, default: "missing"
      add :image_thumbnail_source_url, :text
      add :image_thumbnail_storage_bucket, :string
      add :image_thumbnail_storage_key, :text
      add :image_thumbnail_content_type, :string
      add :image_thumbnail_byte_size, :integer
      add :image_thumbnail_width, :integer
      add :image_thumbnail_height, :integer
      add :image_thumbnail_fetched_at, :utc_datetime_usec
      add :image_thumbnail_attempted_at, :utc_datetime_usec
      add :image_thumbnail_error_reason, :string
      add :image_thumbnail_error_detail, :map, null: false, default: %{}
    end

    create index(:scraped_pages, [:image_thumbnail_status])

    create constraint(:scraped_pages, :scraped_pages_image_thumbnail_status_check,
             check: "image_thumbnail_status IN ('missing', 'pending', 'ready', 'failed')"
           )

    create constraint(:scraped_pages, :scraped_pages_image_thumbnail_byte_size_positive,
             check: "image_thumbnail_byte_size IS NULL OR image_thumbnail_byte_size > 0",
             validate: false
           )

    create constraint(:scraped_pages, :scraped_pages_image_thumbnail_width_positive,
             check: "image_thumbnail_width IS NULL OR image_thumbnail_width > 0",
             validate: false
           )

    create constraint(:scraped_pages, :scraped_pages_image_thumbnail_height_positive,
             check: "image_thumbnail_height IS NULL OR image_thumbnail_height > 0",
             validate: false
           )

    execute(
      """
      ALTER TABLE scraped_pages
        VALIDATE CONSTRAINT scraped_pages_image_thumbnail_byte_size_positive,
        VALIDATE CONSTRAINT scraped_pages_image_thumbnail_width_positive,
        VALIDATE CONSTRAINT scraped_pages_image_thumbnail_height_positive
      """,
      ""
    )
  end
end
