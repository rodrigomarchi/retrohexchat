defmodule RetroHexChat.Repo.Migrations.CreateAutojoinEntries do
  use Ecto.Migration

  def change do
    create table(:autojoin_entries) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :channel_name, :string, null: false, size: 50
      add :channel_key, :string, size: 50
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:autojoin_entries, [:owner_nickname], name: :idx_autojoin_entries_owner)

    create unique_index(
             :autojoin_entries,
             ["lower(owner_nickname)", "lower(channel_name)"],
             name: :idx_autojoin_entries_owner_channel
           )
  end
end
