defmodule RetroHexChat.Repo.Migrations.CreateRegisteredChannels do
  use Ecto.Migration

  def change do
    create table(:registered_channels) do
      add :name, :string, null: false, size: 50
      add :founder_nickname, :string, null: false, size: 16
      add :topic, :text
      add :modes, :string, default: "", size: 50
      add :mode_key, :string, size: 100
      add :mode_limit, :integer
      add :registered_at, :utc_datetime_usec, null: false, default: fragment("now()")

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:registered_channels, [:name], name: :idx_registered_channels_name)
  end
end
