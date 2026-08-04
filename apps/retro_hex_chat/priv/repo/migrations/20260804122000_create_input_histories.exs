defmodule RetroHexChat.Repo.Migrations.CreateInputHistories do
  use Ecto.Migration

  def change do
    create table(:input_histories, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :entries, {:array, :text}, null: false, default: []
      add :recent_commands, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end
  end
end
