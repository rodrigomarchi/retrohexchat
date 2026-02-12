defmodule RetroHexChat.Repo.Migrations.CreatePerformTables do
  use Ecto.Migration

  def change do
    create table(:perform_entries) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :command, :text, null: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:perform_entries, [:owner_nickname], name: :idx_perform_entries_owner)

    create unique_index(:perform_entries, [:owner_nickname, :position],
             name: :idx_perform_entries_owner_position
           )

    create constraint(:perform_entries, :command_length,
             check: "char_length(command) >= 1 AND char_length(command) <= 500"
           )

    create table(:perform_settings, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :enable_on_connect, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end
  end
end
