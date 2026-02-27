defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.ServerMessages do
  @moduledoc """
  PubSub handlers for server-level messages: announcements, wallops, MOTD updates,
  welcome message changes, and admin events (rename, role, mute/unmute).
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, push_status_message: 3]

  alias RetroHexChat.Accounts.Session

  @spec handle_info(tuple(), Phoenix.LiveView.Socket.t()) :: {:halt, Phoenix.LiveView.Socket.t()}

  def handle_info({:announcement, %{content: content}}, socket) do
    msg = %{
      id: "announce-#{System.unique_integer([:positive])}",
      author: "Server",
      content: content,
      type: :announcement,
      timestamp: DateTime.utc_now()
    }

    {:halt, stream_insert(socket, :chat_messages, msg)}
  end

  def handle_info({:wallops, %{sender: sender, content: content}}, socket) do
    session = socket.assigns.session

    if Session.has_mode?(session, :wallops) do
      {:halt, push_status_message(socket, "[Wallops] #{sender}: #{content}", :wallops)}
    else
      {:halt, socket}
    end
  end

  def handle_info({:motd_updated, _payload}, socket) do
    {:halt,
     push_status_message(
       socket,
       "The server Message of the Day has been updated. Type /motd to view.",
       :system
     )}
  end

  def handle_info({:welcome_changed, %{channel: channel, message: message}}, socket) do
    session = socket.assigns.session

    if session.active_channel == channel and message do
      {:halt, system_event(socket, "Welcome message updated.")}
    else
      {:halt, socket}
    end
  end

  # ── Admin events ──────────────────────────────────────────

  def handle_info({:admin_rename, %{old_nick: old_nick, new_nick: new_nick}}, socket) do
    session = socket.assigns.session

    if session.nickname == old_nick do
      new_session = Session.update_nickname(session, new_nick)

      Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nick}")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{new_nick}")

      {:halt,
       socket
       |> assign(session: new_session)
       |> system_event("Your nickname was changed to #{new_nick} by an administrator.")}
    else
      {:halt, socket}
    end
  end

  def handle_info({:role_changed, %{nickname: nick, role: role}}, socket) do
    session = socket.assigns.session

    if session.nickname == nick do
      {:halt, system_event(socket, "Your server role has been changed to: #{role}")}
    else
      {:halt, socket}
    end
  end

  def handle_info({:user_muted, %{nickname: _nick, reason: reason}}, socket) do
    msg = "You have been muted by an administrator" <> if(reason, do: ": #{reason}", else: ".")
    {:halt, system_event(socket, msg)}
  end

  def handle_info({:user_unmuted, _}, socket) do
    {:halt, system_event(socket, "You have been unmuted by an administrator.")}
  end

  def handle_info({:server_setting_changed, %{key: key, value: value}}, socket) do
    {:halt, system_event(socket, "Server setting '#{key}' changed to '#{value}'.")}
  end

  def handle_info({:system_nuked, _}, socket) do
    {:halt, system_event(socket, "System reset initiated by an administrator.")}
  end
end
