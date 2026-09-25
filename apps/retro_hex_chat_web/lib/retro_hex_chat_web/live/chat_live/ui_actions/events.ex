defmodule RetroHexChatWeb.ChatLive.UiActions.Events do
  @moduledoc """
  The three things `/event` asks the chat to do: open the list, schedule, call off.

  Nothing here decides who may. The channel does — whether somebody can put
  something on the calendar is a question about this channel right now, and it
  is asked where the membership lives.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2, system_event: 2]

  alias RetroHexChat.Channels.Server
  alias RetroHexChatWeb.ChatLive.EventEvents

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_events_dialog, _payload), do: EventEvents.open(socket)

  def handle_ui_action(socket, :create_event, payload) do
    starts_at = DateTime.add(DateTime.utc_now(), payload.starts_in_seconds, :second)

    case Server.schedule_event(payload.channel, socket.assigns.session.nickname, %{
           title: payload.title,
           starts_at: starts_at
         }) do
      {:ok, _card} -> EventEvents.refresh_window(socket)
      {:error, message} -> error_event(socket, message)
    end
  end

  def handle_ui_action(socket, :cancel_event, payload) do
    case Server.cancel_event(payload.channel, socket.assigns.session.nickname, payload.event_id) do
      {:ok, card} ->
        socket
        |> EventEvents.refresh_card(card.event_id)
        |> EventEvents.refresh_window()
        |> system_event(dgettext("chat", "%{title} was called off.", title: card.title))

      {:error, message} ->
        error_event(socket, message)
    end
  end
end
