defmodule RetroHexChatWeb.ChatLive.Helpers.Notifications do
  @moduledoc """
  Notification push event helpers for ChatLive.

  Builds notification payloads per contracts/liveview-events.md and pushes
  them to the client-side NotificationDispatcherHook.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChat.Chat.NotificationRouter

  @max_entries 50

  @spec maybe_push_notification(
          Phoenix.LiveView.Socket.t(),
          atom(),
          map()
        ) :: Phoenix.LiveView.Socket.t()
  def maybe_push_notification(socket, event_type, attrs) do
    session = socket.assigns.session
    channel = Map.get(attrs, :channel)
    highlighted = Map.get(attrs, :highlighted, false)

    prefs = session.user_preferences.notifications

    case NotificationRouter.should_notify?(event_type, channel, prefs, session.active_channel) do
      {:notify, _type} ->
        payload = build_notification_event(event_type, attrs, highlighted)

        socket
        |> push_event("notify", payload)
        |> add_notification_entry(payload)

      :dnd_silent ->
        payload = build_notification_event(event_type, attrs, highlighted)

        socket
        |> push_event("notify", payload)
        |> add_notification_entry(payload)

      :skip ->
        socket
    end
  end

  @spec add_notification_entry(Phoenix.LiveView.Socket.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  def add_notification_entry(socket, entry) do
    entries = [entry | socket.assigns.notification_entries]
    trimmed = Enum.take(entries, @max_entries)
    count = socket.assigns.notification_count + 1

    assign(socket, notification_entries: trimmed, notification_count: count)
  end

  @spec build_notification_event(atom(), map(), boolean()) :: map()
  def build_notification_event(event_type, attrs, highlighted) do
    content = Map.get(attrs, :content, "")
    truncated = String.slice(content, 0, 100)

    %{
      id: "notif_#{System.unique_integer([:positive])}",
      type: Atom.to_string(event_type),
      channel: Map.get(attrs, :channel),
      sender: Map.get(attrs, :sender, "Unknown"),
      content: truncated,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      highlighted: highlighted
    }
  end
end
