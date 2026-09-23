defmodule RetroHexChat.Repo.Migrations.CreateMessageReactions do
  use Ecto.Migration

  def change do
    create table(:message_reactions) do
      # A channel message and a private message are the same idea stored in two
      # tables, and this is where that stops being copied: one reaction table
      # with two nullable parents and a check that exactly one is filled, rather
      # than a third fork of the same columns.
      add :message_id, references(:messages, on_delete: :delete_all)
      add :private_message_id, references(:private_messages, on_delete: :delete_all)

      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :emoji, :string, size: 32, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create constraint(:message_reactions, :message_reactions_one_parent,
             check:
               "(message_id IS NOT NULL AND private_message_id IS NULL) OR " <>
                 "(message_id IS NULL AND private_message_id IS NOT NULL)"
           )

    # One person reacts with one emoji once. The uniqueness is what makes the
    # toggle a toggle instead of a counter anybody can run up.
    create unique_index(:message_reactions, [:message_id, :owner_nickname, :emoji],
             where: "message_id IS NOT NULL",
             name: :message_reactions_channel_unique_index
           )

    create unique_index(:message_reactions, [:private_message_id, :owner_nickname, :emoji],
             where: "private_message_id IS NOT NULL",
             name: :message_reactions_private_unique_index
           )

    create index(:message_reactions, [:message_id])
    create index(:message_reactions, [:private_message_id])
  end
end
