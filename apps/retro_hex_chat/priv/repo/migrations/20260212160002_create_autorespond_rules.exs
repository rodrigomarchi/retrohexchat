defmodule RetroHexChat.Repo.Migrations.CreateAutorespondRules do
  use Ecto.Migration

  def change do
    create table(:autorespond_rules) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :trigger_event, :string, null: false, size: 15
      add :channel_filter, :string, size: 50
      add :command, :string, null: false, size: 500
      add :enabled, :boolean, null: false, default: true
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:autorespond_rules, [:owner_nickname])
  end
end
