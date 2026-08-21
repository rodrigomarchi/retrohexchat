defmodule RetroHexChat.Repo.Migrations.EnrichScrapedPages do
  use Ecto.Migration

  def change do
    alter table(:scraped_pages) do
      add :excerpt, :text
      add :image_alt, :text
      add :modified_at, :utc_datetime_usec
      add :section, :text
      add :tags, {:array, :text}, null: false, default: []
      add :content_word_count, :integer
    end

    create constraint(:scraped_pages, :scraped_pages_content_word_count_non_negative,
             check: "content_word_count IS NULL OR content_word_count >= 0",
             validate: false
           )

    execute(
      "ALTER TABLE scraped_pages VALIDATE CONSTRAINT scraped_pages_content_word_count_non_negative",
      ""
    )
  end
end
