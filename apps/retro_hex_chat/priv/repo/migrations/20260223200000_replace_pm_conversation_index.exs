defmodule RetroHexChat.Repo.Migrations.ReplacePmConversationIndex do
  use Ecto.Migration

  def change do
    # Drop the old collation-dependent index
    drop_if_exists index(:private_messages, [], name: :idx_pm_conversation)

    # Create two composite indexes that support the OR-based query:
    # WHERE (sender = A AND recipient = B) OR (sender = B AND recipient = A)
    create index(:private_messages, [:sender_nickname, :recipient_nickname, :id],
             name: :idx_pm_conversation_sr
           )

    create index(:private_messages, [:recipient_nickname, :sender_nickname, :id],
             name: :idx_pm_conversation_rs
           )
  end
end
