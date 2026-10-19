defmodule RetroHexChat.Repo.Migrations.AddPublicToGameResults do
  use Ecto.Migration

  def change do
    alter table(:game_results) do
      add :public, :boolean, null: false, default: true
    end
  end
end
