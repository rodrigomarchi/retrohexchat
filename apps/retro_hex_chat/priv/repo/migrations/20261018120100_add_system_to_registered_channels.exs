defmodule RetroHexChat.Repo.Migrations.AddSystemToRegisteredChannels do
  use Ecto.Migration

  def change do
    alter table(:registered_channels) do
      add :system, :boolean, null: false, default: false
    end
  end
end
