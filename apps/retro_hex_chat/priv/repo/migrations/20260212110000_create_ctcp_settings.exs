defmodule RetroHexChat.Repo.Migrations.CreateCtcpSettings do
  use Ecto.Migration

  def change do
    create table(:ctcp_settings, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :enabled, :boolean, null: false, default: true
      add :version_string, :string, null: false, default: "RetroHexChat v1.0", size: 200
      add :finger_text, :string, null: true, size: 200

      timestamps(type: :utc_datetime_usec)
    end
  end
end
