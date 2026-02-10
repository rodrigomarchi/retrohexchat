defmodule RetroHexChat.Repo.Migrations.CreateAccessListEntries do
  use Ecto.Migration

  def change do
    create table(:access_list_entries) do
      add :channel_name, :string, null: false, size: 50
      add :nickname, :string, null: false, size: 16
      add :level, :string, null: false, size: 10
      add :added_by, :string, null: false, size: 16

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:access_list_entries, [:channel_name, :nickname],
             name: :idx_access_list_channel_nickname
           )

    create index(:access_list_entries, [:channel_name, :level],
             name: :idx_access_list_channel_level
           )
  end
end
