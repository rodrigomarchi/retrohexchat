defmodule RetroHexChat.Channels.ServerEventsTest do
  @moduledoc """
  Scheduling through the channel, and the refusal that matters.

  Whether somebody may put something on the calendar is a question about this
  channel right now, so it is asked where the membership lives. A regular member
  typing the command must be turned down there, not merely not offered a button.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.ScheduledEvents
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Topics

  setup do
    channel = "#sev#{System.unique_integer([:positive])}"
    {:ok, pid} = ChannelSupervisor.start_child(channel)
    on_exit(fn -> if Process.alive?(pid), do: ChannelSupervisor.stop_child(pid) end)

    {:ok, _state} = Server.join(channel, "Ada")
    {:ok, _state} = Server.join(channel, "Grace")

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))

    %{channel: channel, host: "Ada", member: "Grace"}
  end

  defp attrs(overrides \\ []) do
    %{
      title: Keyword.get(overrides, :title, "Tuesday tournament"),
      starts_at:
        Keyword.get(overrides, :starts_at, DateTime.add(DateTime.utc_now(), 7200, :second))
    }
  end

  test "an operator schedules it and the room is told", ctx do
    assert {:ok, card} = Server.schedule_event(ctx.channel, ctx.host, attrs())

    assert card.title == "Tuesday tournament"
    assert_receive {:event_scheduled, ^card}
  end

  # The room decorates the announcement as it arrives, and there is no second
  # chance: the refresh that follows only lands on a row already on screen, so a
  # reader who decorates a millisecond too early gets no card and is never told
  # again. The event therefore has to know which line announced it *before* that
  # line is broadcast.
  test "the line is already attached to the event when the room hears it", ctx do
    # Scheduled from somewhere else so this process is a subscriber like any
    # reader: it is handed the line while the channel is still working, which is
    # exactly the moment a reader decorates it.
    parent = self()

    # `async: false` here, so the sandbox connection is shared and the spawned
    # process can use it.
    spawn_link(fn ->
      send(parent, {:scheduled, Server.schedule_event(ctx.channel, ctx.host, attrs())})
    end)

    assert_receive %{event: "new_message", payload: %{id: message_id}}
    cards = ScheduledEvents.cards_for_messages([message_id])

    assert_receive {:scheduled, {:ok, _card}}
    assert map_size(cards) == 1
  end

  # The line is what the card hangs off: without it the conversation shows
  # nothing at all about an event that was just created.
  test "the room gets a line, and the event points at it", ctx do
    {:ok, card} = Server.schedule_event(ctx.channel, ctx.host, attrs())

    event = ScheduledEvents.get(card.event_id)

    assert event.announcement_message_id
    assert %{content: content} = Queries.get_message(event.announcement_message_id)
    assert content =~ "Tuesday tournament"

    cards = ScheduledEvents.cards_for_messages([event.announcement_message_id])
    assert Map.fetch!(cards, event.announcement_message_id).event_id == event.id
  end

  test "a regular member is refused", ctx do
    assert {:error, message} = Server.schedule_event(ctx.channel, ctx.member, attrs())
    assert message =~ "operator"

    assert ScheduledEvents.list(ctx.channel).items == []
  end

  describe "cancelling" do
    test "whoever scheduled it can call it off", ctx do
      {:ok, card} = Server.schedule_event(ctx.channel, ctx.host, attrs())

      assert {:ok, cancelled} = Server.cancel_event(ctx.channel, ctx.host, card.event_id)
      assert cancelled.cancelled?
      assert_receive {:event_cancelled, _card}
      assert ScheduledEvents.list(ctx.channel).items == []
    end

    test "a regular member cannot", ctx do
      {:ok, card} = Server.schedule_event(ctx.channel, ctx.host, attrs())

      assert {:error, _message} = Server.cancel_event(ctx.channel, ctx.member, card.event_id)
      assert [_still_there] = ScheduledEvents.list(ctx.channel).items
    end

    # An id is a number somebody can type, so the channel has to check that the
    # number is one of its own.
    test "an event from another channel is refused", ctx do
      elsewhere = "#oth#{System.unique_integer([:positive])}"

      {:ok, stranger} =
        ScheduledEvents.create(elsewhere, ctx.host, attrs() |> Map.to_list() |> Map.new())

      assert {:error, _message} = Server.cancel_event(ctx.channel, ctx.host, stranger.id)
      refute ScheduledEvents.get(stranger.id).cancelled_at
    end
  end
end
