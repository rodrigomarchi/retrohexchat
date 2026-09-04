defmodule RetroHexChat.Repo.Migrations.DropUnwrittenColumns do
  use Ecto.Migration

  # Columns and one whole table that no code path ever writes.
  #
  # `user_preferences` held a single centralized row per person. Preferences are
  # kept per concern now and written through `Chat.PreferencePersistence`, which
  # never touches this table; two earlier migrations trimmed columns off it
  # without anyone noticing that nothing reads or writes what was left.
  #
  # `preview_storage_key` is absent from the only builder of upload attributes,
  # and a track's `mid`/`rid` are absent from both places that build track
  # attributes and from the payload sent to a client.
  def up do
    alter table(:chat_uploaded_files) do
      remove :preview_storage_key
    end

    alter table(:group_call_tracks) do
      remove :mid
      remove :rid
    end

    drop table(:user_preferences)
  end

  def down do
    alter table(:chat_uploaded_files) do
      add :preview_storage_key, :string
    end

    alter table(:group_call_tracks) do
      add :mid, :string
      add :rid, :string
    end

    create table(:user_preferences, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :display_settings, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end
  end
end
