defmodule RetroHexChat.Repo.Migrations.DropScrapedPageContentText do
  use Ecto.Migration

  # The extracted article body, which cost more than everything else in the
  # database put together.
  #
  # `content_text` held up to 200k characters per page and was read in exactly
  # one place: a word count, to print "N min read" on a link card. That number
  # has had its own column, `content_word_count`, since the enrichment migration,
  # so the text was answering a question the row could already answer. At 774k
  # rows it was 5.8 GB of TOAST — 78% of the database and the reason the disk
  # filled on 2026-09-21.
  #
  # `content_text_truncated` recorded whether that text had hit the cap. Nothing
  # in `lib/` ever read it.
  #
  # Rows whose `content_word_count` is null keep their card and simply show no
  # reading time until the page is scraped again; the extractor has always
  # written the count on a fresh extraction.
  def up do
    alter table(:scraped_pages) do
      remove :content_text
      remove :content_text_truncated
    end

    # One rewrite of every row, doing three things at once because a rewrite is
    # the expensive part and a row can only be rewritten once per transaction.
    #
    # `last_accessed_at` was only ever written by the feed path, so for a page
    # that merely appears in chat it recorded when the row was written, not when
    # anyone last read it. Pruning on a column that measured the wrong thing
    # would delete pages that are on screen every day, so every row gets one
    # fresh window in which the corrected `Store.touch_access_many/2` can record
    # a real read before the prune is allowed to judge it.
    #
    # `raw_metadata["json_ld"]` kept the whole decoded graph, and a news site
    # ships the article inside it — the same text the column above stored, held
    # a second time under a different name. `Scraper.HTTP` stops writing those
    # keys; this clears the copies already on disk.
    #
    # And a rewritten row no longer carries the column dropped above, which is
    # what actually releases the TOAST rather than merely orphaning it.
    execute """
    UPDATE scraped_pages
    SET last_accessed_at = NOW(),
        raw_metadata =
          CASE
            WHEN jsonb_typeof(raw_metadata -> 'json_ld') = 'array' THEN
              jsonb_set(raw_metadata, '{json_ld}', (
                SELECT coalesce(
                         jsonb_agg(
                           CASE
                             WHEN jsonb_typeof(node) = 'object'
                             THEN node - 'articleBody' - 'text' - 'reviewBody'
                             ELSE node
                           END
                         ),
                         '[]'::jsonb
                       )
                FROM jsonb_array_elements(raw_metadata -> 'json_ld') AS node
              ))
            ELSE raw_metadata
          END
    """
  end

  # The columns come back empty, the touched timestamps stay touched, and the
  # JSON-LD article bodies stay gone. All of it is only recoverable by scraping
  # each page again, which is what bumping `Store.scraper_version/0` would force.
  def down do
    alter table(:scraped_pages) do
      add :content_text, :text
      add :content_text_truncated, :boolean, null: false, default: false
    end
  end
end
