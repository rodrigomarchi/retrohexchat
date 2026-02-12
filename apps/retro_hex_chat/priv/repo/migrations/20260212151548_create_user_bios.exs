defmodule RetroHexChat.Repo.Migrations.CreateUserBios do
  use Ecto.Migration

  def change do
    create table(:user_bios, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :bio_text, :string, null: false, size: 200

      timestamps(type: :utc_datetime_usec)
    end
  end
end
