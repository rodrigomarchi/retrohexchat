defmodule RetroHexChat.Repo.Migrations.DropKeybindingsAndMessageSettings do
  use Ecto.Migration

  def change do
    alter table(:user_preferences) do
      remove :key_bindings, :map, default: %{}
      remove :message_settings, :map, default: %{}
    end
  end
end
