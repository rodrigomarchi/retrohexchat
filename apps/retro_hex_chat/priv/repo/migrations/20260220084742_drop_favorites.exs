defmodule RetroHexChat.Repo.Migrations.DropFavorites do
  use Ecto.Migration

  def up do
    drop_if_exists table(:favorites)
  end

  def down do
    create table(:favorites) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel_name, :string, null: false
      add :description, :string, default: ""
      add :password, :string
      add :auto_join, :boolean, default: false
      add :position, :integer, null: false

      timestamps()
    end

    create index(:favorites, [:user_id])
    create unique_index(:favorites, [:user_id, :channel_name])
  end
end
