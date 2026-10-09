defmodule RetroHexChatWeb.ChatLive.SaveEvents do
  @moduledoc """
  Keeping a line for later, and the window that gives it back.

  Saving is made from the message's own menu because nobody reads message ids
  off a screen — the same thing that turned out to be true of pinning. The
  window is reached from Start ▸ Tools, and it is reachable whether or not
  anything is in it: a list you can only open once it has contents is a list
  nobody discovers.

  The two things the window's rows ask for arrive here as messages rather than
  being done inside the island: going to a line is a conversation switch, and
  neither that nor removing a row belongs to a list.

  Attached as `attach_hook(:save_events, :handle_event, ...)` and
  `attach_hook(:save_info, :handle_info, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.SavedMessages
  alias RetroHexChatWeb.ChatLive.Components.SavedDialog
  alias RetroHexChatWeb.ChatLive.Components.UserContextMenus
  alias RetroHexChatWeb.ChatLive.Helpers.Conversation
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Windows

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_event("open_saved_dialog", _params, socket) do
    {:halt, Windows.open(socket, "saved")}
  end

  def handle_event("ctx_chat_save_message", %{"message_id" => id}, socket) do
    {:halt, socket |> change_saved(id, :save) |> close_menu()}
  end

  def handle_event("ctx_chat_unsave_message", %{"message_id" => id}, socket) do
    {:halt, socket |> change_saved(id, :unsave) |> close_menu()}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @spec handle_info(term(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_info({:open_saved, %{channel: channel} = target}, socket)
      when is_binary(channel) do
    socket =
      if channel == socket.assigns.session.active_channel,
        do: socket,
        else: Conversation.activate_channel(socket, channel)

    {:halt, scroll_to(socket, target.message_id)}
  end

  def handle_info({:open_saved, %{counterpart: nickname} = target}, socket)
      when is_binary(nickname) do
    socket =
      if nickname == socket.assigns.session.active_pm,
        do: socket,
        else: Conversation.activate_pm(socket, nickname)

    {:halt, scroll_to(socket, target.message_id)}
  end

  def handle_info({:open_saved, _target}, socket), do: {:halt, socket}

  def handle_info({:remove_saved, saved_id}, socket) do
    nickname = Session.owner(socket.assigns.session)

    socket =
      case SavedMessages.unsave_id(nickname, saved_id) do
        :ok -> refresh(socket, nickname)
        {:error, message} -> Messages.error_event(socket, message)
      end

    {:halt, socket}
  end

  def handle_info({:set_saved_note, saved_id, note}, socket) do
    nickname = Session.owner(socket.assigns.session)

    socket =
      case SavedMessages.set_note(nickname, saved_id, note) do
        :ok -> socket
        {:error, message} -> Messages.error_event(socket, message)
      end

    {:halt, socket}
  end

  def handle_info(_message, socket), do: {:cont, socket}

  @doc """
  Whether this reader already kept the line under the pointer.

  Asked when the menu opens rather than carried on every rendered message: the
  answer is only ever needed for the one line somebody right-clicked.
  """
  @spec saved?(Phoenix.LiveView.Socket.t(), term()) :: boolean()
  def saved?(socket, message_id) do
    case message(socket, message_id) do
      nil -> false
      message -> SavedMessages.saved?(Session.owner(socket.assigns.session), message)
    end
  end

  # A menu item that has done its job must go away. Left standing it covers the
  # next line, so the second right-click lands on the menu instead of the
  # message — which is exactly what it did.
  @spec close_menu(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp close_menu(socket) do
    send_update(UserContextMenus,
      id: UserContextMenus.id(),
      chat_context_menu: UserContextMenus.chat_closed()
    )

    socket
  end

  @spec change_saved(Phoenix.LiveView.Socket.t(), term(), :save | :unsave) ::
          Phoenix.LiveView.Socket.t()
  defp change_saved(socket, raw_id, action) do
    nickname = Session.owner(socket.assigns.session)

    case message(socket, raw_id) do
      nil ->
        Messages.error_event(socket, dgettext("chat", "That message could not be found."))

      message ->
        apply_change(socket, nickname, message, action)
    end
  end

  defp apply_change(socket, nickname, message, :save) do
    case SavedMessages.save(nickname, message) do
      {:ok, _saved} -> refresh(socket, nickname)
      {:error, reason} -> Messages.error_event(socket, reason)
    end
  end

  defp apply_change(socket, nickname, message, :unsave) do
    :ok = SavedMessages.unsave(nickname, message)
    refresh(socket, nickname)
  end

  # The window may be open while the menu is used, and a list that disagrees
  # with what just happened is worse than no list.
  @spec refresh(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  defp refresh(socket, nickname) do
    if Windows.open?(socket, "saved") do
      send_update(SavedDialog, id: SavedDialog.id(), nickname: nickname, reload: true)
    end

    socket
  end

  @spec message(Phoenix.LiveView.Socket.t(), term()) :: struct() | nil
  defp message(socket, raw_id) do
    id = to_integer(raw_id)

    if socket.assigns.session.active_pm,
      do: Queries.get_private_message(id),
      else: Queries.get_message(id)
  end

  @spec scroll_to(Phoenix.LiveView.Socket.t(), integer()) :: Phoenix.LiveView.Socket.t()
  defp scroll_to(socket, message_id) do
    push_event(socket, "scroll_to_message", %{message_id: to_string(message_id)})
  end

  @spec to_integer(term()) :: integer()
  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, _rest} -> id
      :error -> 0
    end
  end

  defp to_integer(_value), do: 0
end
