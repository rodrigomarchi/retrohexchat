defmodule RetroHexChat.Repo.Migrations.AddMutedToSoundSettings do
  use Ecto.Migration

  def change do
    alter table(:sound_settings) do
      add :muted, :boolean, null: false, default: false
    end
  end
end
