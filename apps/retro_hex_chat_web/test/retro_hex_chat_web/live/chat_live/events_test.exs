defmodule RetroHexChatWeb.ChatLive.EventsTest do
  @moduledoc """
  Putting something on the channel's calendar, from the chat.

  The trap this guards is the classic one: a time is stored in UTC and drawn in
  the reader's own zone, and the two readers below are deliberately hours apart.
  A card that showed the same clock time to both would be wrong for at least one
  of them, and it would be wrong silently.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.ScheduledEvents
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.EventsDialog

  setup ctx do
    host = register("Hos")
    guest = register("Gue")
    channel = "#evt#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(host, pre_identified: true) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")

    %{view: view, host: host, guest: guest, channel: channel}
  end

  test "an operator schedules something and the room gets the card", ctx do
    submit_command_sync(ctx.view, "/event 2h Tuesday tournament")

    assert [event] = ScheduledEvents.list(ctx.channel).items
    assert event.title == "Tuesday tournament"
    assert event.announcement_message_id

    assert render(ctx.view) =~ "event-card-#{event.id}"
  end

  # The room, not just the person who typed it. The card hangs off a message the
  # channel broadcasts, and the calendar entry only learns which message that
  # was after the broadcast has gone out — so a second reader decorates the line
  # before there is anything to decorate it with.
  test "a second person in the room gets the card too", ctx do
    {:ok, guest_view, _html} =
      ctx.conn |> chat_conn(ctx.guest, pre_identified: true) |> live(~p"/chat")

    submit_command_sync(guest_view, "/join #{ctx.channel}")

    submit_command_sync(ctx.view, "/event 2h Tuesday tournament")
    [event] = ScheduledEvents.list(ctx.channel).items

    assert render(guest_view) =~ "event-card-#{event.id}"
  end

  test "bare /event opens the window on this channel", ctx do
    submit_command_sync(ctx.view, "/event 2h Tuesday tournament")
    submit_command_sync(ctx.view, "/event")

    assert "events" in assigns(ctx.view).open_windows
    assert events_state(ctx.view).channel == ctx.channel
    assert events_rows(ctx.view) == 1
  end

  test "the Start menu opens the same window", ctx do
    render_click(ctx.view, "toolbar_action", %{"action" => "open_events_dialog"})

    assert "events" in assigns(ctx.view).open_windows
  end

  test "saying you are going counts, once", ctx do
    submit_command_sync(ctx.view, "/event 2h Tuesday tournament")
    [event] = ScheduledEvents.list(ctx.channel).items

    render_click(ctx.view, "event_attend", %{"event_id" => to_string(event.id)})
    render_click(ctx.view, "event_attend", %{"event_id" => to_string(event.id)})

    assert ScheduledEvents.attendees(event.id) == [ctx.host]
  end

  test "changing your mind takes you off the list", ctx do
    submit_command_sync(ctx.view, "/event 2h Tuesday tournament")
    [event] = ScheduledEvents.list(ctx.channel).items

    render_click(ctx.view, "event_attend", %{"event_id" => to_string(event.id)})
    render_click(ctx.view, "event_unattend", %{"event_id" => to_string(event.id)})

    assert ScheduledEvents.attendees(event.id) == []
  end

  test "a regular member is refused, by the channel", ctx do
    {:ok, other_view, _html} =
      build_conn() |> chat_conn(ctx.guest, pre_identified: true) |> live(~p"/chat")

    submit_command_sync(other_view, "/join #{ctx.channel}")
    submit_command_sync(other_view, "/event 2h Their tournament")

    assert ScheduledEvents.list(ctx.channel).items == []
  end

  test "calling it off empties the list and keeps the row", ctx do
    submit_command_sync(ctx.view, "/event 2h Tuesday tournament")
    [event] = ScheduledEvents.list(ctx.channel).items

    submit_command_sync(ctx.view, "/event cancel #{event.id}")

    assert ScheduledEvents.list(ctx.channel).items == []
    assert ScheduledEvents.get(event.id).cancelled_at
  end

  # A card that was called off is still something people have to read, and the
  # card used to be drawn at seven tenths opacity to say so — which is how this
  # product draws a control it has refused. It says it in words instead.
  test "a card that was called off is not dimmed like a disabled control", ctx do
    submit_command_sync(ctx.view, "/event 2h Tuesday tournament")
    [event] = ScheduledEvents.list(ctx.channel).items

    submit_command_sync(ctx.view, "/event cancel #{event.id}")
    card = render(element(ctx.view, ~s([data-testid="event-card-#{event.id}"])))

    assert card =~ ~s(data-event-state="cancelled")
    assert card =~ "Called off"
    refute card =~ "opacity-"
  end

  # The classic trap. The same instant, two readers, two zones — and the card
  # has to say a different clock time to each of them.
  describe "the reader's own clock" do
    test "two zones read the same instant differently", ctx do
      # 18:00 UTC a week from now: always in the future, and late enough that
      # Tokyo (UTC+9) has already turned the page while São Paulo (UTC-3) has not.
      date = Date.add(Date.utc_today(), 7)
      starts_at = DateTime.new!(date, ~T[18:00:00.000000], "Etc/UTC")

      {:ok, _card} =
        Server.schedule_event(ctx.channel, ctx.host, %{
          title: "Tuesday tournament",
          starts_at: starts_at
        })

      submit_command_sync(ctx.view, "/event")

      assert send_update_events(ctx.view, "America/Sao_Paulo") =~ day_month_year(date) <> " 15:00"

      assert send_update_events(ctx.view, "Asia/Tokyo") =~
               day_month_year(Date.add(date, 1)) <> " 03:00"
    end
  end

  defp send_update_events(view, timezone) do
    send(
      view.pid,
      {:window_send_update, EventsDialog,
       [
         id: EventsDialog.id(),
         channel: assigns(view).session.active_channel,
         viewer: assigns(view).session.nickname,
         timezone: timezone,
         reload: true
       ]}
    )

    render(view)
  end

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}"
    {:ok, _} = NickServ.register(nickname, "password123")
    nickname
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  defp events_state(view) do
    {components, _ids, _uuid} = view.pid |> :sys.get_state() |> Map.fetch!(:components)

    Enum.find_value(components, fn
      {_cid, {EventsDialog, _id, a, _private, _prints}} -> a
      _other -> nil
    end)
  end

  defp events_rows(view) do
    view |> events_state() |> Map.fetch!(:paginated) |> Map.fetch!(:events) |> Map.fetch!(:count)
  end

  defp day_month_year(date), do: Calendar.strftime(date, "%d/%m/%Y")
end
