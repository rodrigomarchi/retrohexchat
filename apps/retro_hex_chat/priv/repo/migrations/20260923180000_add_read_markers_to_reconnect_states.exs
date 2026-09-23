defmodule RetroHexChat.Repo.Migrations.AddReadMarkersToReconnectStates do
  use Ecto.Migration

  # Where somebody was in each conversation, beside what they had open. This
  # table already answers "what did this person have on screen"; where they had
  # got to is the same question and belongs in the same row rather than in a
  # table of its own.
  def change do
    alter table(:reconnect_states) do
      add :read_markers, :map, null: false, default: %{}
    end
  end
end
