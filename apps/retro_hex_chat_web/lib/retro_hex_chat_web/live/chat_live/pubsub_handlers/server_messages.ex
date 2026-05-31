defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.ServerMessages do
  @moduledoc """
  PubSub handlers for server-level messages: announcements, wallops, MOTD updates,
  welcome message changes, and admin events (rename, role, mute/unmute).
  """

  import Phoenix.LiveView, only: [stream_insert: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, push_status_message: 3]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Helpers.Session, as: SessionHelper

  @spec handle_info(tuple(), Phoenix.LiveView.Socket.t()) :: {:halt, Phoenix.LiveView.Socket.t()}

  def handle_info({:announcement, %{content: content}}, socket) do
    msg = %{
      id: "announce-#{System.unique_integer([:positive])}",
      author: dgettext("chat", "Server"),
      content: content,
      type: :announcement,
      timestamp: DateTime.utc_now()
    }

    {:halt, stream_insert(socket, :chat_messages, msg)}
  end

  def handle_info({:wallops, %{sender: sender, content: content}}, socket) do
    session = socket.assigns.session

    if Session.has_mode?(session, :wallops) do
      {:halt,
       push_status_message(
         socket,
         dgettext("chat", "[Wallops] %{sender}: %{content}", sender: sender, content: content),
         :wallops
       )}
    else
      {:halt, socket}
    end
  end

  def handle_info({:motd_updated, _payload}, socket) do
    {:halt,
     push_status_message(
       socket,
       dgettext("chat", "The server Message of the Day has been updated. Type /motd to view."),
       :system
     )}
  end

  def handle_info({:welcome_changed, %{channel: channel, message: message}}, socket) do
    session = socket.assigns.session

    if session.active_channel == channel and message do
      {:halt, system_event(socket, dgettext("chat", "Welcome message updated."))}
    else
      {:halt, socket}
    end
  end

  # ── Admin events ──────────────────────────────────────────

  def handle_info({:admin_rename, %{old_nick: old_nick, new_nick: new_nick}}, socket) do
    session = socket.assigns.session

    if session.nickname == old_nick do
      {:halt,
       socket
       |> SessionHelper.handle_nick_change(new_nick)
       |> system_event(
         dgettext("chat", "Your nickname was changed to %{nickname} by an administrator.",
           nickname: new_nick
         )
       )}
    else
      {:halt, socket}
    end
  end

  def handle_info({:role_changed, %{nickname: nick, role: role}}, socket) do
    session = socket.assigns.session

    if session.nickname == nick do
      {:halt,
       system_event(
         socket,
         dgettext("chat", "Your server role has been changed to: %{role}", role: role)
       )}
    else
      {:halt, socket}
    end
  end

  def handle_info({:user_muted, %{nickname: _nick, reason: reason}}, socket) do
    msg =
      if reason do
        dgettext("chat", "You have been muted by an administrator: %{reason}", reason: reason)
      else
        dgettext("chat", "You have been muted by an administrator.")
      end

    {:halt, system_event(socket, msg)}
  end

  def handle_info({:user_unmuted, _}, socket) do
    {:halt, system_event(socket, dgettext("chat", "You have been unmuted by an administrator."))}
  end

  def handle_info({:server_setting_changed, %{key: key, value: value}}, socket) do
    {:halt,
     system_event(
       socket,
       dgettext("chat", "Server setting '%{key}' changed to '%{value}'.", key: key, value: value)
     )}
  end

  def handle_info({:system_nuked, _}, socket) do
    {:halt, system_event(socket, dgettext("chat", "System reset initiated by an administrator."))}
  end
end
