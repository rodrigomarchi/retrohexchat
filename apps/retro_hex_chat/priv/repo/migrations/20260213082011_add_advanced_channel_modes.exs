defmodule RetroHexChat.Repo.Migrations.AddAdvancedChannelModes do
  use Ecto.Migration

  def change do
    alter table(:registered_channels) do
      add :mode_join_throttle, :string, size: 20
    end
  end
end
