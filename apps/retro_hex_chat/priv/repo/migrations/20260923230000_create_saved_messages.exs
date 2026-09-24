defmodule RetroHexChat.Repo.Migrations.CreateSavedMessages do
  use Ecto.Migration

  # What one person kept for later. Private by construction: the row is owned
  # by a nickname and nothing reads it without one, so there is no visibility
  # rule to get wrong later.
  def change do
    create table(:saved_messages) do
      # Two nullable parents and a check that exactly one is filled — the same
      # shape reactions use, rather than a second pair of tables for the same
      # idea stored twice.
      add :message_id, references(:messages, on_delete: :delete_all)
      add :private_message_id, references(:private_messages, on_delete: :delete_all)

      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :note, :string, size: 200

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create constraint(:saved_messages, :saved_messages_one_parent,
             check:
               "(message_id IS NOT NULL AND private_message_id IS NULL) OR " <>
                 "(message_id IS NULL AND private_message_id IS NOT NULL)"
           )

    # Saving twice is the same save, not two.
    create unique_index(:saved_messages, [:owner_nickname, :message_id],
             where: "message_id IS NOT NULL",
             name: :saved_messages_channel_unique_index
           )

    create unique_index(:saved_messages, [:owner_nickname, :private_message_id],
             where: "private_message_id IS NOT NULL",
             name: :saved_messages_private_unique_index
           )

    # The order the window pages in.
    create index(:saved_messages, [:owner_nickname, :id])
  end
end
