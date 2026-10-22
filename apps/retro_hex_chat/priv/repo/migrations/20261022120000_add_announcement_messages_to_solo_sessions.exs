defmodule RetroHexChat.Repo.Migrations.AddAnnouncementMessagesToSoloSessions do
  use Ecto.Migration

  def change do
    alter table(:solo_sessions) do
      add :channel_message_id, references(:messages, on_delete: :nilify_all)
      add :feed_message_id, references(:messages, on_delete: :nilify_all)
    end

    create index(:solo_sessions, [:channel_message_id], where: "channel_message_id IS NOT NULL")
    create index(:solo_sessions, [:feed_message_id], where: "feed_message_id IS NOT NULL")

    # A game's page lists who started it lately and counts its week.
    create index(:solo_sessions, [:game_id, :game_started_at],
             where: "game_started_at IS NOT NULL"
           )
  end
end
