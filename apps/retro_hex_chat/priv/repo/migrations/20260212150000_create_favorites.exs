defmodule RetroHexChat.Repo.Migrations.CreateFavorites do
  use Ecto.Migration

  def change do
    create table(:favorites) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :channel_name, :string, null: false, size: 50
      add :description, :string, size: 200, default: ""
      add :encrypted_password, :text
      add :auto_join, :boolean, null: false, default: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:favorites, [:owner_nickname])

    create unique_index(:favorites, ["lower(owner_nickname)", "lower(channel_name)"],
             name: :favorites_owner_channel_unique
           )
  end
end
