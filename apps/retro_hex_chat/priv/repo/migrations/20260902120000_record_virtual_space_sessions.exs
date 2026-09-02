defmodule RetroHexChat.Repo.Migrations.RecordVirtualSpaceSessions do
  use Ecto.Migration

  def change do
    create table(:virtual_space_sessions) do
      add :token, :string, size: 64, null: false
      add :space_id, :string, size: 100, null: false
      add :kind, :string, size: 20, null: false
      add :status, :string, size: 20, null: false, default: "open"
      add :opened_by, references(:registered_nicks, on_delete: :nilify_all)
      add :opened_by_nick, :string, size: 16, null: false
      add :opened_at, :utc_datetime_usec
      add :closed_at, :utc_datetime_usec
      add :closed_reason, :string, size: 100

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:virtual_space_sessions, [:token])

    create unique_index(:virtual_space_sessions, [:space_id],
             where: "status = 'open'",
             name: :idx_virtual_space_sessions_one_open_per_space
           )

    create index(:virtual_space_sessions, [:space_id, :status])
    create index(:virtual_space_sessions, [:status, :updated_at])

    create table(:virtual_space_session_participants) do
      add :session_id, references(:virtual_space_sessions, on_delete: :delete_all), null: false
      add :nickname, :string, size: 16, null: false
      add :normalized_nickname, :string, size: 16, null: false
      add :joined_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :virtual_space_session_participants,
             [:session_id, :normalized_nickname],
             name: :idx_virtual_space_participants_once
           )
  end
end
