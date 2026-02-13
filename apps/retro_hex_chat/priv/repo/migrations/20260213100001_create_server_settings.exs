defmodule RetroHexChat.Repo.Migrations.CreateServerSettings do
  use Ecto.Migration

  def change do
    create table(:server_settings) do
      add :key, :string, size: 50, null: false
      add :value, :text
      add :updated_by, :string, size: 16

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:server_settings, [:key], name: :idx_server_settings_key)
  end
end
