defmodule RetroHexChatWeb.ChatLive.PinEvents do
  @moduledoc """
  Opening the Pinned window, and the two things its rows ask the chat to do.

  The island owns a list. Going to a line is a conversation scroll and removing
  a pin is a channel operation, and neither belongs to a list — so both arrive
  here as messages from the island rather than being done inside it.

  Attached as `attach_hook(:pin_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Channels.Pins
  alias RetroHexChat.Channels.Server
  alias RetroHexChatWeb.ChatLive.Components.UserContextMenus
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Windows

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_event("open_pinned_dialog", _params, socket) do
    {:halt, Windows.open(socket, "pinned")}
  end

  # The practical way in: nobody reads message ids off a screen, so the menu is
  # how a pin is actually made. The channel checks the permission again when the
  # pin arrives — the menu item only decides whether to draw a button.
  def handle_event("ctx_chat_pin_message", %{"message_id" => id}, socket) do
    {:halt, socket |> change_pin(id, :pin) |> close_menu()}
  end

  def handle_event("ctx_chat_unpin_message", %{"message_id" => id}, socket) do
    {:halt, socket |> change_pin(id, :unpin) |> close_menu()}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @spec handle_info(term(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_info({:open_pinned, _channel, message_id}, socket) do
    {:halt, push_event(socket, "scroll_to_message", %{message_id: to_string(message_id)})}
  end

  def handle_info({:unpin_message, channel, message_id}, socket) do
    nickname = socket.assigns.session.nickname

    socket =
      case Server.unpin_message(channel, nickname, to_integer(message_id)) do
        :ok ->
          assign(socket, pinned_count: Pins.count(channel))

        {:error, message} ->
          Messages.error_event(socket, message)
      end

    {:halt, socket}
  end

  def handle_info(_message, socket), do: {:cont, socket}

  # A menu item that has done its job must go away, or it covers the next line.
  defp close_menu(socket) do
    send_update(UserContextMenus,
      id: UserContextMenus.id(),
      chat_context_menu: UserContextMenus.chat_closed()
    )

    socket
  end

  defp change_pin(socket, raw_id, action) do
    channel = socket.assigns.session.active_channel
    nickname = socket.assigns.session.nickname
    id = to_integer(raw_id)

    result =
      case action do
        :pin -> Server.pin_message(channel, nickname, id)
        :unpin -> Server.unpin_message(channel, nickname, id)
      end

    case result do
      :ok -> assign(socket, pinned_count: Pins.count(channel))
      {:error, message} -> Messages.error_event(socket, message)
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
