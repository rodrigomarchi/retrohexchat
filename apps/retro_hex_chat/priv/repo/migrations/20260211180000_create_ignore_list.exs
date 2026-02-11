defmodule RetroHexChat.Repo.Migrations.CreateIgnoreList do
  use Ecto.Migration

  def change do
    create table(:ignore_list_entries) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :ignored_nickname, :string, null: false, size: 16
      add :ignore_type, :string, null: false, size: 10
      add :expires_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :ignore_list_entries,
             ["lower(owner_nickname)", "lower(ignored_nickname)"],
             name: :idx_ignore_list_owner_ignored
           )

    create index(:ignore_list_entries, [:owner_nickname], name: :idx_ignore_list_owner)
  end
end
