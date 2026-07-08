defmodule RetroHexChat.Repo.Migrations.NormalizeLegacySpaceInviteMessages do
  use Ecto.Migration

  def up do
    execute "UPDATE messages SET type = 'message' WHERE type = 'space_invite'"
    execute "UPDATE private_messages SET type = 'message' WHERE type = 'space_invite'"
  end

  def down do
    :ok
  end
end
