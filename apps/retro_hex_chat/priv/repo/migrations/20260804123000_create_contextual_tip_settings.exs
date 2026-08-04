defmodule RetroHexChat.Repo.Migrations.CreateContextualTipSettings do
  use Ecto.Migration

  def change do
    create table(:contextual_tip_settings, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :seen_tips, {:array, :string}, null: false, default: []
      add :suppressed, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
