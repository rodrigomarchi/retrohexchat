defmodule RetroHexChat.Repo.Migrations.CreateBotGreetings do
  use Ecto.Migration

  def change do
    create table(:bot_greetings) do
      add :bot_id, references(:bots, on_delete: :delete_all), null: false
      add :channel_name, :string, size: 100, null: false
      add :nickname, :string, size: 16, null: false
      add :greeted_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # The ledger is written on the join path, so the lookup that decides whether
    # somebody is new has to be the same index that enforces uniqueness.
    create unique_index(:bot_greetings, [:bot_id, :channel_name, :nickname],
             name: :idx_bot_greetings_recipient
           )

    create index(:bot_greetings, [:greeted_at], name: :idx_bot_greetings_sweep)
  end
end
