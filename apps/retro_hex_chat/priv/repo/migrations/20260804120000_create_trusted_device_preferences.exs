defmodule RetroHexChat.Repo.Migrations.CreateTrustedDevicePreferences do
  use Ecto.Migration

  def change do
    create table(:trusted_device_preferences) do
      add :trusted_device_id, references(:trusted_devices, on_delete: :delete_all), null: false
      add :registered_nick_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :namespace, :string, size: 64, null: false
      add :settings, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :trusted_device_preferences,
             [:trusted_device_id, :registered_nick_id, :namespace],
             name: :trusted_device_preferences_device_nick_namespace_unique
           )

    create index(:trusted_device_preferences, [:registered_nick_id])
    create index(:trusted_device_preferences, [:namespace])
  end
end
