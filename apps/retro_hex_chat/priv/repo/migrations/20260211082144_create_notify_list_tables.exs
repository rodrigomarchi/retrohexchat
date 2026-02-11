defmodule RetroHexChat.Repo.Migrations.CreateNotifyListTables do
  use Ecto.Migration

  def change do
    create table(:notify_list_entries) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :tracked_nickname, :string, null: false, size: 16
      add :note, :string, size: 200
      add :last_seen_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :notify_list_entries,
             ["lower(owner_nickname)", "lower(tracked_nickname)"],
             name: :idx_notify_list_entries_owner_tracked
           )

    create index(:notify_list_entries, [:owner_nickname], name: :idx_notify_list_entries_owner)

    create table(:notify_list_settings, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :auto_whois, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
