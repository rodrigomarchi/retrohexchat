defmodule RetroHexChat.Repo.Migrations.WidenMessagesType do
  use Ecto.Migration

  # "space_invite" (12 chars) exceeds the original varchar(10).
  def up do
    alter table(:messages) do
      modify :type, :string, size: 20
    end
  end

  def down do
    alter table(:messages) do
      modify :type, :string, size: 10
    end
  end
end
