defmodule RetroHexChat.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :channel_name, :string, null: false, size: 50
      add :author_nickname, :string, null: false, size: 16
      add :content, :text, null: false
      add :type, :string, null: false, default: "message", size: 10

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:messages, [:channel_name, :inserted_at],
             name: :idx_messages_channel_inserted_at,
             comment: "Cursor-based pagination"
           )
  end
end
