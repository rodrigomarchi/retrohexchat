defmodule RetroHexChat.Repo.Migrations.AddTrustedDeviceCleanupIndexes do
  use Ecto.Migration

  def change do
    create index(:trusted_devices, [:expires_at],
             name: :trusted_devices_expiry_cleanup_idx,
             where: "revoked_at IS NULL"
           )

    create index(:chat_device_sessions, [:last_seen_at],
             name: :chat_device_sessions_stale_cleanup_idx,
             where: "disconnected_at IS NULL"
           )
  end
end
