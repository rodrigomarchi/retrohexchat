defmodule RetroHexChat.Repo.Migrations.AddNotifySettingsToSoundSettings do
  use Ecto.Migration

  def change do
    alter table(:sound_settings) do
      add :notify_settings, :map, null: false, default: %{}
    end
  end
end
