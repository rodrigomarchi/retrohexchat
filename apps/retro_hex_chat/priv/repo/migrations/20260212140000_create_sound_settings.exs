defmodule RetroHexChat.Repo.Migrations.CreateSoundSettings do
  use Ecto.Migration

  def change do
    create table(:sound_settings, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :sound_mappings, :map, null: false, default: %{}
      add :flash_settings, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end
  end
end
