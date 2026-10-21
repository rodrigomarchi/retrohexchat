defmodule RetroHexChat.Repo.Migrations.AddCategoryToRegisteredChannels do
  use Ecto.Migration

  # What a channel is about, chosen by its founder and drawn as a coloured
  # plaque beside the channel's name. The channels the server keeps for the
  # Retro Games are about games.
  def up do
    alter table(:registered_channels) do
      add :category, :string, size: 16
    end

    execute "UPDATE registered_channels SET category = 'games' WHERE system AND category IS NULL"
  end

  def down do
    alter table(:registered_channels) do
      remove :category
    end
  end
end
