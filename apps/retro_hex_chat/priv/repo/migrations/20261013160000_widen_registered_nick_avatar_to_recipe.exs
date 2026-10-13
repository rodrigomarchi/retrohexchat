defmodule RetroHexChat.Repo.Migrations.WidenRegisteredNickAvatarToRecipe do
  use Ecto.Migration

  # A character is a creator recipe (`VirtualSpace.CharacterRecipe`, at most 64
  # characters), not one of a fixed list of class names. The class names stored
  # so far name art that no longer exists, so they are cleared: the person
  # makes a character the next time they walk into a space.
  def up do
    alter table(:registered_nicks) do
      modify :avatar, :string, size: 64
    end

    execute "UPDATE registered_nicks SET avatar = NULL WHERE avatar IS NOT NULL"
  end

  def down do
    execute "UPDATE registered_nicks SET avatar = NULL WHERE avatar IS NOT NULL"

    alter table(:registered_nicks) do
      modify :avatar, :string, size: 20
    end
  end
end
