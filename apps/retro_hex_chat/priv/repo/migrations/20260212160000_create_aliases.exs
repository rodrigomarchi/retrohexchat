defmodule RetroHexChat.Repo.Migrations.CreateAliases do
  use Ecto.Migration

  def change do
    create table(:aliases) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :name, :string, null: false, size: 30
      add :expansion, :string, null: false, size: 500
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:aliases, [:owner_nickname])

    create unique_index(:aliases, ["lower(owner_nickname)", "lower(name)"],
             name: :aliases_owner_name_unique
           )
  end
end
