defmodule RetroHexChat.Repo.Migrations.AddFloorToVirtualSpaceConstructs do
  use Ecto.Migration

  def change do
    alter table(:virtual_space_constructs) do
      add :floor, :text
    end
  end
end
