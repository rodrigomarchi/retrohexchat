defmodule RetroHexChat.Repo.Migrations.DropReconnectStateTabOrder do
  use Ecto.Migration

  # The tab bar no longer lists every conversation, so there is no user-chosen
  # order left to carry across a reconnect. The column only ever held a display
  # preference — nothing reads it, and losing it costs a session nothing.
  def up do
    alter table(:reconnect_states) do
      remove :tab_order
    end
  end

  def down do
    alter table(:reconnect_states) do
      add :tab_order, {:array, :map}, null: false, default: []
    end
  end
end
