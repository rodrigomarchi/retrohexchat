defmodule RetroHexChat.Repo.Migrations.CreateBanExceptions do
  use Ecto.Migration

  def change do
    create table(:ban_exceptions) do
      add :channel_name, :string, null: false, size: 50
      add :nickname, :string, null: false, size: 16
      add :added_by, :string, null: false, size: 16

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:ban_exceptions, [:channel_name, :nickname],
             name: :idx_ban_exceptions_channel_nickname
           )

    create index(:ban_exceptions, [:channel_name])
  end
end
