defmodule RetroHexChat.Repo.Migrations.AddAutoLoginToTrustedDeviceNicks do
  use Ecto.Migration

  def change do
    alter table(:trusted_device_nicks) do
      add :auto_login, :boolean, null: false, default: false
    end

    create index(:trusted_device_nicks, [:trusted_device_id, :auto_login])
  end
end
