defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.ServerMessages do
  @moduledoc """
  PubSub handlers for server-level messages: announcements, wallops, MOTD updates,
  and welcome message changes.
  """

  import Phoenix.LiveView, only: [stream_insert: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_message: 1, push_status_message: 3]

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
    {:halt, socket}
  end

  def handle_info({:welcome_changed, %{channel: channel, message: message}}, socket) do
    session = socket.assigns.session

    if session.active_channel == channel and message do
      {:halt, stream_insert(socket, :chat_messages, system_message("Welcome message updated."))}
    else
      {:halt, socket}
    end
  end
end
