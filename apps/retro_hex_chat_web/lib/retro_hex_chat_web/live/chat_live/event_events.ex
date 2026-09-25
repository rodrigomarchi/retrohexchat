defmodule RetroHexChatWeb.ChatLive.EventEvents do
  @moduledoc """
  Saying you will be there, and keeping every copy of the card agreeing.

  The same event can be on screen twice — as the card under the line that
  announced it, and as a row in the Events window — and a third time on
  everybody else's screen. So an answer is not a local change: it is written,
  broadcast, and every screen rebuilds the row it is holding from the database.

  The row is rebuilt rather than patched because the count is a query either
  way, and a row assembled by hand carries whatever shape this module happened
  to think of rather than the shape a row has.

  Attached as `attach_hook(:event_events, :handle_event, ...)` and
  `attach_hook(:event_info, :handle_info, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Channels.ScheduledEvents
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.ChatLive.Components.EventsDialog
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.StreamItem
  alias RetroHexChatWeb.ChatLive.Windows

  @window "events"
  @pubsub RetroHexChat.PubSub

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_event("open_events_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  def handle_event("event_attend", %{"event_id" => raw_id}, socket) do
    {:halt, answer(socket, raw_id, :attend)}
  end

  def handle_event("event_unattend", %{"event_id" => raw_id}, socket) do
    {:halt, answer(socket, raw_id, :unattend)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @spec handle_info(term(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_info({:event_rsvp_changed, event_id}, socket) do
    {:halt, socket |> refresh_card(event_id) |> refresh_window()}
  end

  def handle_info(_message, socket), do: {:cont, socket}

  @doc """
  Opens (or focuses) the window on the channel currently on screen.

  Public because the `/event` command reaches it through the ui-action path
  rather than through a DOM event.
  """
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    Windows.open_with(socket, @window, EventsDialog,
      id: EventsDialog.id(),
      channel: socket.assigns.session.active_channel,
      viewer: socket.assigns.session.nickname,
      timezone: socket.assigns.timezone,
      can_schedule: socket.assigns[:can_pin] || false
    )
  end

  @doc "Reloads the window's list, for a change it did not make itself."
  @spec refresh_window(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def refresh_window(socket) do
    if Windows.open?(socket, @window) do
      send_update(EventsDialog,
        id: EventsDialog.id(),
        channel: socket.assigns.session.active_channel,
        viewer: socket.assigns.session.nickname,
        timezone: socket.assigns.timezone,
        reload: true
      )
    end

    socket
  end

  @doc """
  Rebuilds the line an event was announced on, if this viewport is holding it.

  `insert_if_present/2` rather than `insert/2`: the announcement may have
  scrolled out of the loaded page, and a plain insert would draw it a second
  time at the bottom, out of order.
  """
  @spec refresh_card(Phoenix.LiveView.Socket.t(), integer()) :: Phoenix.LiveView.Socket.t()
  def refresh_card(socket, event_id) do
    with %{announcement_message_id: message_id} when is_integer(message_id) <-
           ScheduledEvents.get(event_id),
         %{} = message <- Queries.get_message(message_id) do
      MessageViewport.insert_if_present(socket, StreamItem.from_message(message))
    else
      _nothing_to_refresh -> socket
    end
  end

  @spec answer(Phoenix.LiveView.Socket.t(), term(), :attend | :unattend) ::
          Phoenix.LiveView.Socket.t()
  defp answer(socket, raw_id, action) do
    nickname = socket.assigns.session.nickname
    id = to_integer(raw_id)

    case apply_answer(id, nickname, action) do
      :ok ->
        broadcast_rsvp(id)
        socket |> refresh_card(id) |> refresh_window()

      {:error, message} ->
        Messages.error_event(socket, message)
    end
  end

  defp apply_answer(id, nickname, :attend), do: ScheduledEvents.attend(id, nickname)
  defp apply_answer(id, nickname, :unattend), do: ScheduledEvents.unattend(id, nickname)

  # Everybody's copy of the card carries the headcount, so everybody's copy has
  # to hear about it. The event's own channel is the topic, because that is who
  # can see the card in the first place.
  defp broadcast_rsvp(event_id) do
    case ScheduledEvents.get(event_id) do
      nil ->
        :ok

      event ->
        Phoenix.PubSub.broadcast(
          @pubsub,
          Topics.channel(event.channel_name),
          {:event_rsvp_changed, event_id}
        )
    end
  end

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, _rest} -> id
      :error -> 0
    end
  end

  defp to_integer(_value), do: 0
end
