defmodule RetroHexChat.Repo.Migrations.CreateAdminRoles do
  use Ecto.Migration

  def change do
    create table(:admin_roles) do
      add :nickname, :string, size: 16, null: false
      add :role, :string, size: 20, null: false
      add :granted_by, :string, size: 16, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:admin_roles, [:nickname, :role])
    create index(:admin_roles, [:nickname])
  end
end
