defmodule RetroHexChat.Repo.Migrations.CreateVirtualSpaceConstructs do
  use Ecto.Migration

  def change do
    create table(:virtual_space_constructs) do
      add :space_id, :string, size: 120, null: false
      add :items, {:array, :map}, null: false, default: []
      add :revision, :integer, null: false, default: 0
      add :updated_by_nick, :string, size: 16

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:virtual_space_constructs, [:space_id])
  end
end
