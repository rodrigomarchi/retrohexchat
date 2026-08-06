defmodule RetroHexChat.Repo.Migrations.CreateGlobalMutes do
  use Ecto.Migration

  def change do
    create table(:global_mutes) do
      add :nickname, :string, size: 16, null: false
      add :normalized_nickname, :string, size: 16, null: false
      add :operator_nickname, :string, size: 16, null: false
      add :reason, :string, size: 255
      add :expires_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      add :revoked_by_nickname, :string, size: 16
      add :revoke_reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:global_mutes, [:normalized_nickname],
             where: "revoked_at IS NULL",
             name: :idx_global_mutes_active_nickname
           )

    create index(:global_mutes, [:expires_at],
             where: "revoked_at IS NULL AND expires_at IS NOT NULL",
             name: :idx_global_mutes_expiry
           )
  end
end
