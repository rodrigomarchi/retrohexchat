defmodule RetroHexChatWeb.ChatLive.MentionEvents do
  @moduledoc """
  Opening the Mentions window, and following one of its rows back to the line.

  Following a mention is a conversation switch plus a scroll, and both belong to
  the host rather than to the window: the island owns a list. The scroll is the
  same push the reply block uses, with the same fallback for a message that is
  older than the page currently loaded — a mention from two days ago is exactly
  the case where that happens.

  Attached as an `attach_hook(:mention_events, :handle_event, ...)` and a
  matching `handle_info` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.ChatLive.Helpers.Conversation
  alias RetroHexChatWeb.ChatLive.Windows

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_event("open_mentions", _params, socket) do
    {:halt, Windows.open(socket, "mentions")}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Follow a row from the Mentions window to the message it names.

  Sent by the island rather than pushed from the template, because what happens
  next — switching conversation, loading its history — is the host's, and a
  LiveComponent that reached for it would be reaching outside itself.
  """
  @spec handle_info(term(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_info({:open_mention, channel, message_id}, socket) do
    socket =
      if channel == socket.assigns.session.active_channel do
        socket
      else
        Conversation.activate_channel(socket, channel)
      end

    {:halt, push_event(socket, "scroll_to_message", %{message_id: to_string(message_id)})}
  end

  def handle_info(_message, socket), do: {:cont, socket}
end
