defmodule RetroHexChat.Repo.Migrations.CreateBots do
  use Ecto.Migration

  def change do
    create table(:bots) do
      add :name, :string, null: false
      add :nickname, :string, null: false
      add :description, :string
      add :command_prefix, :string, null: false, default: "!"
      add :created_by, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :cooldown_ms, :integer, null: false, default: 2000
      add :capabilities, :map, null: false, default: %{}

      add :stats, :map,
        null: false,
        default: %{"messages_handled" => 0, "commands_processed" => 0}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:bots, [:name], name: :bots_name_index)
    create unique_index(:bots, [:nickname], name: :bots_nickname_index)

    create table(:bot_channel_configs) do
      add :bot_id, references(:bots, on_delete: :delete_all), null: false
      add :channel_name, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :capability_overrides, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:bot_channel_configs, [:bot_id, :channel_name],
             name: :bot_channel_configs_bot_id_channel_name_index
           )

    create index(:bot_channel_configs, [:bot_id])

    create table(:bot_custom_commands) do
      add :bot_id, references(:bots, on_delete: :delete_all), null: false
      add :trigger, :string, null: false
      add :response, :text, null: false
      add :description, :string
      add :enabled, :boolean, null: false, default: true
      add :added_by, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:bot_custom_commands, [:bot_id, :trigger],
             name: :bot_custom_commands_bot_id_trigger_index
           )

    create index(:bot_custom_commands, [:bot_id])

    create table(:bot_event_log) do
      add :bot_id, references(:bots, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :channel, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:bot_event_log, [:bot_id])
    create index(:bot_event_log, [:inserted_at])
  end
end
