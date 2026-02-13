defmodule RetroHexChat.Repo.Migrations.CreateChannelWelcomeMessages do
  use Ecto.Migration

  def change do
    create table(:channel_welcome_messages) do
      add :channel_name, :string, size: 50, null: false
      add :message, :text, null: false
      add :set_by, :string, size: 16, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:channel_welcome_messages, [:channel_name],
             name: :idx_channel_welcome_messages_channel_name
           )
  end
end
