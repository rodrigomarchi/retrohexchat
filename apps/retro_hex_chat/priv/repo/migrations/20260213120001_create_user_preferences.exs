defmodule RetroHexChat.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :display_settings, :map, null: false, default: %{}
      add :font_settings, :map, null: false, default: %{}
      add :color_settings, :map, null: false, default: %{}
      add :connect_settings, :map, null: false, default: %{}
      add :message_settings, :map, null: false, default: %{}
      add :key_bindings, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end
  end
end
