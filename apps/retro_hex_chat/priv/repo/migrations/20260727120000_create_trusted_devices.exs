defmodule RetroHexChat.Repo.Migrations.CreateTrustedDevices do
  use Ecto.Migration

  def change do
    create table(:trusted_devices) do
      add :selector, :string, size: 64, null: false
      add :token_hash, :string, size: 128, null: false
      add :label, :string, size: 100
      add :browser, :string, size: 100
      add :os, :string, size: 100
      add :device_type, :string, size: 32
      add :language, :string, size: 32
      add :timezone, :string, size: 100
      add :screen, :string, size: 32
      add :color_depth, :integer
      add :touch, :boolean, null: false, default: false
      add :cores, :integer
      add :user_agent_hash, :string, size: 64
      add :last_ip_hash, :string, size: 64
      add :first_seen_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :last_seen_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :expires_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      add :revoked_by_nickname, :string, size: 16

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:trusted_devices, [:selector])
    create index(:trusted_devices, [:expires_at])
    create index(:trusted_devices, [:revoked_at])

    create table(:trusted_device_nicks) do
      add :trusted_device_id, references(:trusted_devices, on_delete: :delete_all), null: false
      add :registered_nick_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :granted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :last_used_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      add :revoked_by_nickname, :string, size: 16

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:trusted_device_nicks, [:trusted_device_id, :registered_nick_id],
             name: :trusted_device_nicks_device_nick_unique
           )

    create index(:trusted_device_nicks, [:registered_nick_id])
    create index(:trusted_device_nicks, [:revoked_at])

    create table(:chat_device_sessions) do
      add :session_ref, :string, size: 64, null: false
      add :trusted_device_id, references(:trusted_devices, on_delete: :nilify_all)
      add :registered_nick_id, references(:registered_nicks, on_delete: :nilify_all)
      add :nickname, :string, size: 16, null: false
      add :client_info, :map, null: false, default: %{}
      add :connected_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :last_seen_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :disconnected_at, :utc_datetime_usec
      add :disconnect_reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:chat_device_sessions, [:session_ref])
    create index(:chat_device_sessions, [:nickname])
    create index(:chat_device_sessions, [:registered_nick_id])
    create index(:chat_device_sessions, [:trusted_device_id])
    create index(:chat_device_sessions, [:disconnected_at])

    create table(:trusted_device_events) do
      add :trusted_device_id, references(:trusted_devices, on_delete: :nilify_all)
      add :registered_nick_id, references(:registered_nicks, on_delete: :nilify_all)
      add :actor_nickname, :string, size: 16
      add :action, :string, size: 64, null: false
      add :details, :map, null: false, default: %{}
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:trusted_device_events, [:registered_nick_id])
    create index(:trusted_device_events, [:trusted_device_id])
    create index(:trusted_device_events, [:action])
    create index(:trusted_device_events, [:inserted_at])
  end
end
