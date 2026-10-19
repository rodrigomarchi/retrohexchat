defmodule RetroHexChat.Repo.Migrations.CreateGameRatings do
  use Ecto.Migration

  def change do
    create table(:game_ratings) do
      add :base_id, :string, size: 30, null: false
      add :player_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :rating, :integer, null: false
      add :matches, :integer, null: false, default: 0
      add :wins, :integer, null: false, default: 0
      add :losses, :integer, null: false, default: 0
      add :draws, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:game_ratings, [:base_id, :player_id])
    create index(:game_ratings, [:base_id, :rating])
  end
end
