defmodule RetroHexChatWeb.ChatLive.ThreadEvents do
  @moduledoc """
  Opening a thread, and keeping it and the room agreeing with each other.

  A thread is a reading over the replies that already exist, so nothing here
  writes: it opens the window on one root, and when a reply arrives while that
  window is open it puts the line in the list and re-counts the root's line in
  the conversation.

  Re-counting is the part that needs care. The root may have scrolled out of
  the loaded page, and a stream insert of a row the stream does not have
  **appends** it — the root would appear a second time at the bottom, out of
  order, in the middle of a live conversation. So the viewport is asked to
  refresh the row only if it is holding it.

  Replying is the room's: this aims the conversation's own composer at the root
  rather than growing a second input, because the reply is going to appear in
  the room either way.

  Attached as `attach_hook(:thread_events, :handle_event, ...)` and
  `attach_hook(:thread_info, :handle_info, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Replies
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Components.ThreadDialog
  alias RetroHexChatWeb.ChatLive.Components.UserContextMenus
  alias RetroHexChatWeb.ChatLive.CoreEvents
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.StreamItem
  alias RetroHexChatWeb.ChatLive.Windows

  @window "thread"

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_event("open_thread", %{"message_id" => raw_id}, socket) do
    kind = kind(socket)

    case Replies.root_id(reply_kind(kind), to_integer(raw_id)) do
      nil ->
        {:halt,
         Messages.error_event(socket, dgettext("chat", "That message could not be found."))}

      root_id ->
        {:halt, socket |> open(kind, root_id) |> close_menu()}
    end
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @spec handle_info(term(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_info({:thread_reply, _kind, nil}, socket), do: {:halt, socket}

  def handle_info({:thread_reply, _kind, root_id}, socket) do
    CoreEvents.handle_event(
      "reply_to_message",
      %{"message_id" => to_string(root_id)},
      socket
    )
  end

  def handle_info({:thread_open_message, message_id}, socket) do
    {:halt, push_event(socket, "scroll_to_message", %{message_id: to_string(message_id)})}
  end

  def handle_info(_message, socket), do: {:cont, socket}

  @doc """
  Records a reply that just arrived: the root's counter, and the open thread.

  Called from the message PubSub handler with the row it already built, so the
  reply is drawn by the same thing that drew every other line.
  """
  @spec reply_arrived(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def reply_arrived(socket, %{reply_to_id: root_id} = item) when is_integer(root_id) do
    kind = kind(socket)

    socket
    |> recount_root(kind, root_id)
    |> forward_to_thread(kind, root_id, item)
  end

  def reply_arrived(socket, _item), do: socket

  @doc "How many replies a message has, for the menu that offers to open them."
  @spec reply_count(Phoenix.LiveView.Socket.t(), term()) :: non_neg_integer()
  def reply_count(socket, message_id) do
    socket
    |> kind()
    |> Queries.thread_counts_for_many([to_integer(message_id)])
    |> Map.values()
    |> List.first()
    |> Kernel.||(0)
  end

  @spec open(Phoenix.LiveView.Socket.t(), atom(), integer()) :: Phoenix.LiveView.Socket.t()
  defp open(socket, kind, root_id) do
    Windows.open_with(socket, @window, ThreadDialog,
      id: ThreadDialog.id(),
      kind: kind,
      root_id: root_id
    )
  end

  defp recount_root(socket, kind, root_id) do
    case root_row(kind, root_id) do
      nil -> socket
      row -> MessageViewport.insert_if_present(socket, row)
    end
  end

  defp forward_to_thread(socket, kind, root_id, item) do
    if Windows.open?(socket, @window) do
      send_update(ThreadDialog,
        id: ThreadDialog.id(),
        kind: kind,
        root_id: root_id,
        action: {:reply_arrived, ThreadDialog.without_quote(item)}
      )
    end

    socket
  end

  # Rebuilt from the database rather than patched in memory: the count is a
  # query either way, and a row assembled by hand is a row that has whatever
  # shape this module happened to think of.
  defp root_row(:message, id) do
    case Queries.get_message(id) do
      nil -> nil
      message -> [message] |> StreamItem.from_messages() |> List.first()
    end
  end

  defp root_row(:private_message, id) do
    case Queries.get_private_message(id) do
      nil -> nil
      pm -> [pm] |> StreamItem.from_private_messages() |> List.first()
    end
  end

  defp kind(socket) do
    if socket.assigns.session.active_pm, do: :private_message, else: :message
  end

  # `Chat.Replies` spells the private kind `:pm`; the queries spell it
  # `:private_message`. One of them has to translate, and it is not the domain.
  defp reply_kind(:private_message), do: :pm
  defp reply_kind(:message), do: :message

  defp close_menu(socket) do
    send_update(UserContextMenus,
      id: UserContextMenus.id(),
      chat_context_menu: UserContextMenus.chat_closed()
    )

    socket
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
