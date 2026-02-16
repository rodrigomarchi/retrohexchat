defmodule RetroHexChat.Repo.Migrations.AddMessageInteractions do
  use Ecto.Migration

  def change do
    # Messages table — reply, edit, delete fields
    alter table(:messages) do
      add :reply_to_id, references(:messages, on_delete: :nilify_all)
      add :reply_to_author, :string, size: 16
      add :reply_to_preview, :string, size: 100
      add :edited_at, :utc_datetime_usec
      add :deleted_at, :utc_datetime_usec
    end

    create index(:messages, [:reply_to_id])

    # Private messages table — same fields (self-referential FK)
    alter table(:private_messages) do
      add :reply_to_id, references(:private_messages, on_delete: :nilify_all)
      add :reply_to_author, :string, size: 16
      add :reply_to_preview, :string, size: 100
      add :edited_at, :utc_datetime_usec
      add :deleted_at, :utc_datetime_usec
    end

    create index(:private_messages, [:reply_to_id])
  end
end
