defmodule RetroHexChat.Repo.Migrations.AddLocaleToRegisteredChannels do
  use Ecto.Migration

  # The language a channel is spoken in, chosen by its founder and drawn as a
  # flag beside the channel's name. The channels the server keeps for the
  # Retro Games are English.
  def up do
    alter table(:registered_channels) do
      add :locale, :string, size: 16
    end

    execute "UPDATE registered_channels SET locale = 'en' WHERE system AND locale IS NULL"
  end

  def down do
    alter table(:registered_channels) do
      remove :locale
    end
  end
end
