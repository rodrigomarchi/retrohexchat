defmodule RetroHexChat.Repo.Migrations.CreateServerBans do
  use Ecto.Migration

  def change do
    create table(:server_bans) do
      add :nickname, :string, size: 16, null: false
      add :reason, :text
      add :banned_by, :string, size: 16, null: false
      add :expires_at, :utc_datetime_usec
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:server_bans, [:nickname],
             where: "active = true",
             name: :idx_server_bans_active_nickname
           )

    create index(:server_bans, [:active, :expires_at])
  end
end
