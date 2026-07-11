defmodule RetroHexChat.Repo.Migrations.CreateGroupCallTables do
  use Ecto.Migration

  def change do
    create table(:group_call_rooms) do
      add :token, :string, size: 64, null: false
      add :channel_name, :string, size: 100, null: false
      add :creator_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :creator_nick, :string, size: 16, null: false
      add :title, :string, size: 100
      add :status, :string, size: 20, null: false, default: "pending"
      add :max_participants, :integer, null: false, default: 100
      add :media_policy, :map, null: false, default: %{}
      add :codec_policy, :map, null: false, default: %{}
      add :ice_policy, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}
      add :opened_at, :utc_datetime_usec
      add :activated_at, :utc_datetime_usec
      add :last_activity_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec
      add :closed_at, :utc_datetime_usec
      add :closed_reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:group_call_rooms, [:token])

    create unique_index(:group_call_rooms, [:channel_name],
             where: "status NOT IN ('closed', 'expired', 'failed')",
             name: :idx_group_call_rooms_one_active_per_channel
           )

    create index(:group_call_rooms, [:channel_name, :status])
    create index(:group_call_rooms, [:status, :last_activity_at])
    create index(:group_call_rooms, [:creator_id])
    create index(:group_call_rooms, [:expires_at])

    create table(:group_call_participants) do
      add :room_id, references(:group_call_rooms, on_delete: :delete_all), null: false
      add :registered_nick_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :nickname, :string, size: 16, null: false
      add :normalized_nickname, :string, size: 16, null: false
      add :channel_role_snapshot, :string, size: 20, null: false, default: "regular"
      add :status, :string, size: 20, null: false, default: "joining"
      add :peer_ref, :string, size: 128
      add :media_state, :map, null: false, default: %{}
      add :client_info, :map, null: false, default: %{}
      add :joined_at, :utc_datetime_usec
      add :connected_at, :utc_datetime_usec
      add :last_seen_at, :utc_datetime_usec
      add :disconnected_at, :utc_datetime_usec
      add :left_at, :utc_datetime_usec
      add :reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:group_call_participants, [:room_id, :normalized_nickname],
             where: "status NOT IN ('left', 'kicked', 'failed')",
             name: :idx_group_call_participants_active_nick
           )

    create index(:group_call_participants, [:room_id, :status])
    create index(:group_call_participants, [:registered_nick_id])
    create index(:group_call_participants, [:last_seen_at])

    create table(:group_call_tracks) do
      add :room_id, references(:group_call_rooms, on_delete: :delete_all), null: false

      add :participant_id, references(:group_call_participants, on_delete: :delete_all),
        null: false

      add :kind, :string, size: 10, null: false
      add :source, :string, size: 30, null: false
      add :webrtc_track_id, :string, size: 128, null: false
      add :stream_id, :string, size: 128
      add :mid, :string, size: 32
      add :rid, :string, size: 32
      add :status, :string, size: 20, null: false, default: "announced"
      add :codec, :string, size: 50
      add :metadata, :map, null: false, default: %{}
      add :announced_at, :utc_datetime_usec
      add :activated_at, :utc_datetime_usec
      add :muted_at, :utc_datetime_usec
      add :ended_at, :utc_datetime_usec
      add :ended_reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:group_call_tracks, [:participant_id, :kind, :source],
             where: "status NOT IN ('ended', 'failed')",
             name: :idx_group_call_tracks_active_source
           )

    create index(:group_call_tracks, [:room_id, :status])
    create index(:group_call_tracks, [:participant_id, :status])
    create index(:group_call_tracks, [:webrtc_track_id])
  end
end
