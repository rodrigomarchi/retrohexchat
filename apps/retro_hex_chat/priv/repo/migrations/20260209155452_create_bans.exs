defmodule RetroHexChat.Repo.Migrations.CreateBans do
  use Ecto.Migration

  def change do
    create table(:bans) do
      add :channel_name, :string, null: false, size: 50
      add :banned_nickname, :string, null: false, size: 16
      add :banned_by, :string, null: false, size: 16
      add :reason, :string, size: 255

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:bans, [:channel_name, :banned_nickname],
             name: :idx_bans_channel_nickname
           )

    create index(:bans, [:channel_name], name: :idx_bans_channel)
  end
end
