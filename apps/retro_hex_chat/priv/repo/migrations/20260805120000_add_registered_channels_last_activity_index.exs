defmodule RetroHexChat.Repo.Migrations.AddRegisteredChannelsLastActivityIndex do
  use Ecto.Migration

  def change do
    create index(:registered_channels, [:last_activity_at],
             name: :idx_registered_channels_last_activity_at
           )
  end
end
