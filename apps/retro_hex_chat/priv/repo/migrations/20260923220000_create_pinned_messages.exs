defmodule RetroHexChat.Repo.Migrations.CreatePinnedMessages do
  use Ecto.Migration

  # A pin belongs to the conversation, not to the message: the same line is
  # ordinary everywhere else, and a column on `messages` would say otherwise.
  def change do
    create table(:pinned_messages) do
      add :channel_name, :string, null: false, size: 50
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :pinned_by, :string, null: false, size: 16

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # Pinning twice is the same pin, not two.
    create unique_index(:pinned_messages, [:channel_name, :message_id])

    # The order the window pages in.
    create index(:pinned_messages, [:channel_name, :id])
  end
end
