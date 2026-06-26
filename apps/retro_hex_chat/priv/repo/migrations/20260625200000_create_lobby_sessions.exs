defmodule RetroHexChat.Repo.Migrations.CreateLobbySessions do
  use Ecto.Migration

  def change do
    create table(:lobby_sessions) do
      add :token, :string, size: 64, null: false
      add :creator_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :peer_id, references(:registered_nicks, on_delete: :delete_all), null: false
      add :status, :string, size: 20, null: false, default: "pending"
      add :metadata, :map, null: false, default: %{}
      add :accepted_at, :utc_datetime_usec
      add :connected_at, :utc_datetime_usec
      add :closed_at, :utc_datetime_usec
      add :closed_reason, :string, size: 100
      add :duration_seconds, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:lobby_sessions, [:token])
    create index(:lobby_sessions, [:creator_id])
    create index(:lobby_sessions, [:peer_id])
    create index(:lobby_sessions, [:status])
    create index(:lobby_sessions, [:creator_id, :peer_id, :status])
  end
end
