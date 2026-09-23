defmodule RetroHexChat.Repo.Migrations.CreatePushSubscriptions do
  use Ecto.Migration

  def change do
    create table(:push_subscriptions) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :endpoint, :text, null: false
      add :p256dh, :string, null: false
      add :auth, :string, null: false
      add :user_agent, :string
      add :last_success_at, :utc_datetime_usec
      add :failure_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    # One row per browser: the endpoint is the browser's own address at its push
    # service, so a second subscribe from the same device must replace the row
    # rather than double every notification it gets.
    create unique_index(:push_subscriptions, [:endpoint])
    create index(:push_subscriptions, [:owner_nickname])

    # A mention is matched case-insensitively against the nickname, and the
    # plain index above cannot serve that comparison.
    create index(:push_subscriptions, ["lower(owner_nickname)"],
             name: :push_subscriptions_lower_owner_nickname_index
           )
  end
end
