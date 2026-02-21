defmodule RetroHexChat.Repo.Migrations.AddLastActivityAtToRegisteredChannels do
  use Ecto.Migration

  def change do
    alter table(:registered_channels) do
      add :last_activity_at, :utc_datetime_usec
    end

    execute(
      "UPDATE registered_channels SET last_activity_at = COALESCE(updated_at, registered_at, NOW())",
      "SELECT 1"
    )

    alter table(:registered_channels) do
      modify :last_activity_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end
  end
end
