defmodule RetroHexChat.Repo.Migrations.RemoveCtcpSettings do
  use Ecto.Migration

  def up do
    drop table(:ctcp_settings)

    alter table(:flood_protection_settings) do
      remove :ctcp_reply_limit
      remove :ctcp_reply_window_seconds
    end
  end

  def down do
    create table(:ctcp_settings, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          primary_key: true,
          size: 16

      add :enabled, :boolean, default: true, null: false
      add :version_string, :string, size: 200, default: "RetroHexChat v1.0"
      add :finger_text, :string, size: 200

      timestamps(type: :utc_datetime_usec)
    end

    alter table(:flood_protection_settings) do
      add :ctcp_reply_limit, :integer, default: 2
      add :ctcp_reply_window_seconds, :integer, default: 10
    end
  end
end
