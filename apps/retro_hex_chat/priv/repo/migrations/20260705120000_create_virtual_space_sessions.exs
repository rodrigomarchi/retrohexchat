defmodule RetroHexChat.Repo.Migrations.CreateVirtualSpaceSessions do
  use Ecto.Migration

  def change do
    create table(:virtual_space_sessions) do
      add :token, :string, size: 64, null: false
      add :channel_name, :string, size: 100, null: false
      add :creator_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :creator_nick, :string, size: 50, null: false
      add :title, :string, size: 100
      add :status, :string, size: 20, null: false, default: "pending"
      add :map_id, :string, size: 50, null: false, default: "tavern_cafe_v1"
      add :max_participants, :integer, null: false, default: 20
      add :last_participant_count, :integer, null: false, default: 0
      add :peak_participants, :integer, null: false, default: 0
      add :metadata, :map, null: false, default: %{}
      add :activated_at, :utc_datetime_usec
      add :last_activity_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec
      add :closed_at, :utc_datetime_usec
      add :closed_reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:virtual_space_sessions, [:token])
    create index(:virtual_space_sessions, [:channel_name, :status])
    create index(:virtual_space_sessions, [:creator_id])
    create index(:virtual_space_sessions, [:status])
    create index(:virtual_space_sessions, [:expires_at])
  end
end
