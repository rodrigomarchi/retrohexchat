defmodule RetroHexChat.Repo.Migrations.DropDeadPreferenceColumns do
  use Ecto.Migration

  def change do
    alter table(:user_preferences) do
      remove :font_settings, :map, default: %{}
      remove :color_settings, :map, default: %{}
      remove :connect_settings, :map, default: %{}
    end
  end
end
