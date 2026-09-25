defmodule RetroHexChat.Channels.EventsScheduledTest do
  @moduledoc """
  Something a channel agreed to do, at a time.

  Two things here are the whole feature and both are about time: an event that
  has already happened never reminds anybody, and the stored instant is UTC no
  matter who wrote it. Everything else — the answer, the list, the card — is
  bookkeeping around those two.
  """
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Channels.ScheduledEvents
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Page

  setup do
    %{channel: "#ev#{System.unique_integer([:positive])}", host: "Ada", guest: "Grace"}
  end

  defp in_hours(hours), do: DateTime.add(DateTime.utc_now(), hours * 3600, :second)

  defp create(ctx, opts \\ []) do
    {:ok, event} =
      ScheduledEvents.create(ctx.channel, ctx.host, %{
        title: Keyword.get(opts, :title, "Tuesday tournament"),
        description: Keyword.get(opts, :description),
        starts_at: Keyword.get(opts, :starts_at, in_hours(3)),
        surface_hint: Keyword.get(opts, :surface_hint)
      })

    event
  end

  describe "create/3" do
    test "keeps the instant it was given, in UTC", ctx do
      at = in_hours(5)
      event = create(ctx, starts_at: at)

      assert event.starts_at == at
      assert event.starts_at.time_zone == "Etc/UTC"
      assert event.created_by == ctx.host
      refute event.cancelled_at
    end

    test "refuses an event in the past", ctx do
      assert {:error, message} =
               ScheduledEvents.create(ctx.channel, ctx.host, %{
                 title: "Yesterday",
                 starts_at: in_hours(-1)
               })

      assert message =~ "past"
    end

    test "refuses a nameless event", ctx do
      assert {:error, _message} =
               ScheduledEvents.create(ctx.channel, ctx.host, %{
                 title: "   ",
                 starts_at: in_hours(1)
               })
    end
  end

  describe "list/2" do
    test "reads soonest first, under Page", ctx do
      late = create(ctx, title: "Late", starts_at: in_hours(9))
      early = create(ctx, title: "Early", starts_at: in_hours(1))
      middle = create(ctx, title: "Middle", starts_at: in_hours(5))

      page = ScheduledEvents.list(ctx.channel, limit: 2)

      assert Enum.map(page.items, & &1.id) == [early.id, middle.id]
      assert page.has_more
      assert page.next_cursor

      rest = ScheduledEvents.list(ctx.channel, limit: 2, cursor: page.next_cursor)

      assert Enum.map(rest.items, & &1.id) == [late.id]
      refute rest.has_more
    end

    test "another channel's events are another channel's", ctx do
      create(ctx)

      assert %Page{items: []} =
               ScheduledEvents.list("#elsewhere#{System.unique_integer([:positive])}")
    end

    test "carries how many people said they would be there", ctx do
      event = create(ctx)
      :ok = ScheduledEvents.attend(event.id, ctx.guest)

      assert [%{attendee_count: 1}] = ScheduledEvents.list(ctx.channel).items
    end
  end

  describe "attend/2" do
    test "saying it twice is saying it once", ctx do
      event = create(ctx)

      :ok = ScheduledEvents.attend(event.id, ctx.guest)
      :ok = ScheduledEvents.attend(event.id, ctx.guest)

      assert ScheduledEvents.attendees(event.id) == [ctx.guest]
      assert ScheduledEvents.attending?(event.id, ctx.guest)
    end

    test "changing your mind removes you", ctx do
      event = create(ctx)
      :ok = ScheduledEvents.attend(event.id, ctx.guest)
      :ok = ScheduledEvents.unattend(event.id, ctx.guest)

      assert ScheduledEvents.attendees(event.id) == []
      refute ScheduledEvents.attending?(event.id, ctx.guest)
    end

    test "a cancelled event takes no more answers", ctx do
      event = create(ctx)
      {:ok, _cancelled} = ScheduledEvents.cancel(event.id, ctx.host)

      assert {:error, _message} = ScheduledEvents.attend(event.id, ctx.guest)
    end
  end

  describe "cancel/2" do
    test "keeps the row and stops counting it as upcoming", ctx do
      event = create(ctx)
      {:ok, cancelled} = ScheduledEvents.cancel(event.id, ctx.host)

      assert cancelled.cancelled_at
      assert ScheduledEvents.get(event.id)
      assert ScheduledEvents.list(ctx.channel).items == []
    end

    test "only the person who created it may", ctx do
      event = create(ctx)

      assert {:error, _message} = ScheduledEvents.cancel(event.id, ctx.guest)
    end
  end

  describe "due_for_reminder/2" do
    test "an event inside the window is due", ctx do
      soon = create(ctx, title: "Soon", starts_at: DateTime.add(DateTime.utc_now(), 600, :second))
      _later = create(ctx, title: "Later", starts_at: in_hours(6))

      assert [%{id: id}] = ScheduledEvents.due_for_reminder(DateTime.utc_now(), 900)
      assert id == soon.id
    end

    # The assertion the whole worker exists to keep: a reminder for something
    # that already happened is a notification nobody can act on.
    test "an event that already started is never due", ctx do
      _event = create(ctx, starts_at: DateTime.add(DateTime.utc_now(), 600, :second))
      later = DateTime.add(DateTime.utc_now(), 1200, :second)

      assert ScheduledEvents.due_for_reminder(later, 900) == []
    end

    test "an event already reminded is not reminded again", ctx do
      event = create(ctx, starts_at: DateTime.add(DateTime.utc_now(), 600, :second))
      {1, nil} = ScheduledEvents.mark_reminded([event.id], DateTime.utc_now())

      assert ScheduledEvents.due_for_reminder(DateTime.utc_now(), 900) == []
    end

    test "a cancelled event is never due", ctx do
      event = create(ctx, starts_at: DateTime.add(DateTime.utc_now(), 600, :second))
      {:ok, _cancelled} = ScheduledEvents.cancel(event.id, ctx.host)

      assert ScheduledEvents.due_for_reminder(DateTime.utc_now(), 900) == []
    end
  end

  describe "cards_for_messages/1" do
    test "answers for a whole page in one query", ctx do
      event = create(ctx)

      {:ok, message} =
        Queries.insert_message(%{
          channel_name: ctx.channel,
          author_nickname: ctx.host,
          content: "Tuesday tournament — in 3 hours",
          type: "message"
        })

      {:ok, _attached} = ScheduledEvents.attach_announcement(event, message.id)

      cards = ScheduledEvents.cards_for_messages([message.id])
      card = Map.fetch!(cards, message.id)

      assert card.title == "Tuesday tournament"
      assert card.event_id == event.id
    end

    test "says nothing about a message that announced nothing" do
      assert ScheduledEvents.cards_for_messages([]) == %{}
    end
  end
end
