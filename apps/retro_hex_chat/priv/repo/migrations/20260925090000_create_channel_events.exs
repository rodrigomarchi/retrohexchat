defmodule RetroHexChat.Repo.Migrations.CreateChannelEvents do
  use Ecto.Migration

  # An event belongs to a channel, and a channel is a name here — the same
  # decision pins and saved messages already made. `starts_at` is UTC like every
  # other timestamp in this database; the reader's clock is applied when it is
  # drawn, never when it is stored.
  def change do
    create table(:channel_events) do
      add :channel_name, :string, null: false, size: 50
      add :title, :string, null: false, size: 120
      add :description, :string, size: 500
      add :starts_at, :utc_datetime_usec, null: false
      add :created_by, :string, null: false, size: 16

      # What the event is for, when it is for something this product can open:
      # a game id, or "space" for the channel's own place. Free text with no
      # foreign key on purpose — a game that is retired must not delete the
      # record that people met to play it.
      add :surface_hint, :string, size: 40

      # The line the channel got when the event was announced, so the card can
      # be drawn under it without the message table knowing what an event is.
      add :announcement_message_id, references(:messages, on_delete: :nilify_all)

      add :cancelled_at, :utc_datetime_usec

      # When the reminder went out. The sweep runs on a schedule and would
      # otherwise find the same event every time it ran.
      add :reminded_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    # The order both the window and the reminder sweep read in.
    create index(:channel_events, [:channel_name, :starts_at])

    # The card lookup for a page of messages.
    create index(:channel_events, [:announcement_message_id])

    create table(:channel_event_attendees) do
      add :event_id, references(:channel_events, on_delete: :delete_all), null: false
      add :nickname, :string, null: false, size: 16

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # Saying you are going twice is the same answer, not two.
    create unique_index(:channel_event_attendees, [:event_id, :nickname])
    create index(:channel_event_attendees, [:nickname])
  end
end
