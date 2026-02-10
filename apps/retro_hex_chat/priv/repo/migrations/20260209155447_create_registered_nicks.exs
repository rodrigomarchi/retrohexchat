defmodule RetroHexChat.Repo.Migrations.CreateRegisteredNicks do
  use Ecto.Migration

  def change do
    create table(:registered_nicks) do
      add :nickname, :string, null: false, size: 16
      add :password_hash, :string, null: false, size: 255
      add :registered_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :last_seen_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:registered_nicks, [:nickname], name: :idx_registered_nicks_nickname)
  end
end
