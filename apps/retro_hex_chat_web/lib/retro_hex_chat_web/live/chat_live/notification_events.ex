defmodule RetroHexChatWeb.ChatLive.NotificationEvents do
  @moduledoc """
  Handle notification-related events from the client.

  Events:
  - `toggle_dnd` — Toggle Do Not Disturb mode
  - `toggle_notification_center` — Open/close notification center panel
  - `mark_all_notifications_read` — Clear all notification entries
  - `click_notification` — Navigate to the source of a notification
  - `browser_permission_result` — Browser notification permission result
  - `navigate_to_channel` — Navigate to channel from toast click

  Attached as `attach_hook(:notification_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{NotificationPreferences, Service, UserPreferences}
  alias RetroHexChat.P2P
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.ChatLive.Helpers

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def handle_event("toggle_dnd", _params, socket) do
    session = socket.assigns.session
    prefs = session.user_preferences
    notif = prefs.notifications
    new_dnd = !notif.dnd_enabled
    updated_notif = NotificationPreferences.set_dnd_enabled(notif, new_dnd)
    updated_prefs = UserPreferences.set_notifications(prefs, updated_notif)
    updated_session = Session.set_user_preferences(session, updated_prefs)

    socket =
      socket
      |> assign(session: updated_session, dnd_enabled: new_dnd)
      |> push_event("dnd_changed", %{enabled: new_dnd})
      |> push_event("update_notification_prefs", NotificationPreferences.to_map(updated_notif))
      |> Helpers.Persistence.maybe_persist_user_preferences(updated_session)

    {:halt, socket}
  end

  def handle_event("toggle_notification_center", _params, socket) do
    show = !socket.assigns.show_notification_center
    {:halt, assign(socket, show_notification_center: show)}
  end

  def handle_event("mark_all_notifications_read", _params, socket) do
    socket =
      socket
      |> assign(
        notification_entries: [],
        notification_count: 0,
        show_notification_center: false,
        unread_counts: %{},
        highlight_channels: MapSet.new(),
        flash_channels: MapSet.new()
      )
      |> push_event("clear_favicon_badge", %{})

    {:halt, socket}
  end

  def handle_event("click_notification", %{"id" => id}, socket) do
    entry = Enum.find(socket.assigns.notification_entries, &(&1.id == id))
    socket = navigate_to_notification(socket, entry)
    {:halt, assign(socket, show_notification_center: false)}
  end

  def handle_event("browser_permission_result", %{"permission" => permission}, socket) do
    session = socket.assigns.session
    prefs = session.user_preferences
    notif = prefs.notifications

    enabled = permission == "granted"
    updated_notif = NotificationPreferences.set_browser_notifications(notif, enabled)
    updated_prefs = UserPreferences.set_notifications(prefs, updated_notif)
    updated_session = Session.set_user_preferences(session, updated_prefs)

    socket =
      socket
      |> assign(session: updated_session)
      |> push_event("update_notification_prefs", NotificationPreferences.to_map(updated_notif))
      |> Helpers.Persistence.maybe_persist_user_preferences(updated_session)

    {:halt, socket}
  end

  def handle_event("accept_p2p", %{"token" => token}, socket) do
    {:halt, Phoenix.LiveView.push_navigate(socket, to: "/p2p/#{token}")}
  end

  def handle_event("reject_p2p", %{"token" => token, "from" => from}, socket) do
    session = socket.assigns.session

    nick = session.nickname
    identified = session.identified

    socket =
      if identified do
        case RegisteredNick |> RetroHexChat.Repo.get_by(nickname: nick) do
          nil ->
            socket

          reg_nick ->
            P2P.close_session(token, reg_nick.id, "rejected")

            Service.send_private_message(
              nick,
              from,
              "#{nick} recusou o convite P2P.",
              "p2p_invite"
            )

            socket
        end
      else
        socket
      end

    {:halt, socket}
  end

  def handle_event("reject_p2p", %{"token" => token}, socket) do
    handle_event("reject_p2p", %{"token" => token, "from" => ""}, socket)
  end

  def handle_event("navigate_to_channel", %{"channel" => channel}, socket) do
    session = socket.assigns.session

    socket =
      if channel in session.channels do
        updated_session = Session.set_active_channel(session, channel)
        assign(socket, session: updated_session)
      else
        socket
      end

    {:halt, socket}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp navigate_to_notification(socket, nil), do: socket
  defp navigate_to_notification(socket, %{channel: nil}), do: socket

  defp navigate_to_notification(socket, %{channel: "pm:" <> target}) do
    Helpers.open_pm_conversation(socket, target)
  end

  defp navigate_to_notification(socket, %{channel: channel}) do
    session = socket.assigns.session

    if channel in session.channels do
      assign(socket, session: Session.set_active_channel(session, channel))
    else
      socket
    end
  end
end
