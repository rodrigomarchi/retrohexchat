defmodule RetroHexChat.Repo.Migrations.CreateChannelMutes do
  use Ecto.Migration

  def change do
    create table(:channel_mutes) do
      add :channel_name, :string, size: 100, null: false
      add :target_nickname, :string, size: 16, null: false
      add :normalized_target, :string, size: 16, null: false
      add :operator_nickname, :string, size: 16, null: false
      add :reason, :string, size: 255
      add :expires_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      add :revoked_by_nickname, :string, size: 16
      add :revoke_reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:channel_mutes, [:channel_name, :normalized_target],
             where: "revoked_at IS NULL",
             name: :idx_channel_mutes_active_target
           )

    create index(:channel_mutes, [:channel_name],
             where: "revoked_at IS NULL",
             name: :idx_channel_mutes_active_channel
           )

    create index(:channel_mutes, [:expires_at],
             where: "revoked_at IS NULL AND expires_at IS NOT NULL",
             name: :idx_channel_mutes_expiry
           )
  end
end
