defmodule RetroHexChat.Repo.Migrations.CreatePrivateMessages do
  use Ecto.Migration

  def change do
    create table(:private_messages) do
      add :sender_nickname, :string, null: false, size: 16
      add :recipient_nickname, :string, null: false, size: 16
      add :content, :text, null: false
      add :type, :string, null: false, default: "message", size: 10

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:private_messages, [:recipient_nickname, :inserted_at],
             name: :idx_pm_recipient,
             comment: "Finding PMs for a recipient"
           )

    # Composite index for conversation lookup using sorted nicknames
    execute(
      """
      CREATE INDEX idx_pm_conversation ON private_messages (
        LEAST(sender_nickname, recipient_nickname),
        GREATEST(sender_nickname, recipient_nickname),
        inserted_at DESC
      )
      """,
      "DROP INDEX idx_pm_conversation"
    )
  end
end
