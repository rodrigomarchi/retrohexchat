defmodule RetroHexChat.Repo.Migrations.IndexRepliesByParent do
  use Ecto.Migration

  # A thread is read and counted by its parent, in id order: the page of
  # replies, and the reply count of every root on a page of fifty lines. The
  # composite answers both from the index alone and covers everything the
  # single-column index did, so that one goes.
  def up do
    create index(:messages, [:reply_to_id, :id])
    drop_if_exists index(:messages, [:reply_to_id])

    create index(:private_messages, [:reply_to_id, :id])
    drop_if_exists index(:private_messages, [:reply_to_id])
  end

  def down do
    create index(:messages, [:reply_to_id])
    drop_if_exists index(:messages, [:reply_to_id, :id])

    create index(:private_messages, [:reply_to_id])
    drop_if_exists index(:private_messages, [:reply_to_id, :id])
  end
end
