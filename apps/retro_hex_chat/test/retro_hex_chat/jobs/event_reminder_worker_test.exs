defmodule RetroHexChat.Jobs.EventReminderWorkerTest do
  @moduledoc """
  The sweep that tells a channel something is about to start.

  What matters is what it refuses: an event that already started, one that was
  called off, and one it has already announced. A reminder is the single
  interruption this product is allowed to make about an event, and each of
  those three would spend it on something nobody can act on.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.ScheduledEvents
  alias RetroHexChat.Jobs.EventReminderWorker
  alias RetroHexChat.Topics

  setup do
    channel = "#rem#{System.unique_integer([:positive])}"
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))

    %{channel: channel, host: "Ada", guest: "Grace"}
  end

  defp event_at(ctx, seconds, title \\ "Tuesday tournament") do
    {:ok, event} =
      ScheduledEvents.create(ctx.channel, ctx.host, %{
        title: title,
        starts_at: DateTime.add(DateTime.utc_now(), seconds, :second)
      })

    event
  end

  test "announces an event inside the window to the room", ctx do
    event = event_at(ctx, 600)
    :ok = ScheduledEvents.attend(event.id, ctx.guest)

    assert {:ok, %{reminded: 1, notified: 1}} =
             EventReminderWorker.remind(DateTime.utc_now(), 900)

    assert_received {:event_reminder, card}
    assert card.event_id == event.id
    assert card.title == "Tuesday tournament"
  end

  test "says nothing about an event further out than the window", ctx do
    _event = event_at(ctx, 6 * 3600)

    assert {:ok, %{reminded: 0}} = EventReminderWorker.remind(DateTime.utc_now(), 900)
    refute_received {:event_reminder, _card}
  end

  # Absence, sabotaged and reverted: the same event must not be announced twice.
  test "announces an event once, however often it sweeps", ctx do
    _event = event_at(ctx, 600)

    assert {:ok, %{reminded: 1}} = EventReminderWorker.remind(DateTime.utc_now(), 900)
    assert_received {:event_reminder, _first}

    assert {:ok, %{reminded: 0}} = EventReminderWorker.remind(DateTime.utc_now(), 900)
    refute_received {:event_reminder, _second}
  end

  test "says nothing about an event that was called off", ctx do
    event = event_at(ctx, 600)
    {:ok, _cancelled} = ScheduledEvents.cancel(event.id, ctx.host)

    assert {:ok, %{reminded: 0}} = EventReminderWorker.remind(DateTime.utc_now(), 900)
    refute_received {:event_reminder, _card}
  end

  test "counts nobody when nobody said they would be there", ctx do
    _event = event_at(ctx, 600)

    assert {:ok, %{reminded: 1, notified: 0}} =
             EventReminderWorker.remind(DateTime.utc_now(), 900)
  end
end
