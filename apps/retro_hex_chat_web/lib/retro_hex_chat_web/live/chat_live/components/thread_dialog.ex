defmodule RetroHexChatWeb.ChatLive.Components.ThreadDialog do
  @moduledoc """
  Stateful island behind the Thread window.

  Holds one thread: the message that started it and the page of replies under
  it, read forwards. It loads on the first `update/2` rather than on a message
  sent after mount — a window that asks for its contents afterwards races the
  patch that put it on screen, and the reader watches an empty list blink into
  a full one.

  Opening a different thread is a different list, so a new `root_id` reloads;
  anything else that re-renders the parent must not.

  The rows are built without their own reply counts. A reply can never collect
  replies (`Chat.Replies`), and the root drawing "3 replies" inside the very
  window those three replies are already in would be a door back into the room
  you are standing in.

  The replies are printed on the room's continuous paper (`MessageGrouping`):
  a run of one person shares a header and a band. `reply_tail` is the last
  reply shown, which the next page and a reply arriving continue from.

  Writing is the room's: `thread_reply` asks the host to aim the conversation's
  composer at this thread, because that is where the reply is going to appear.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.ThreadDialog

  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Chat.Queries
  alias RetroHexChatWeb.ChatLive.MessageGrouping
  alias RetroHexChatWeb.ChatLive.StreamItem
  alias RetroHexChatWeb.PaginatedList

  @page_size 25

  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "thread-dialog",
    initial: %{
      root_id: nil,
      kind: :message,
      root: nil,
      nick_color_fn: nil,
      timestamp_format: :time,
      timezone: "Etc/UTC",
      strip_formatting: false,
      viewer: nil,
      loaded_root_id: :none,
      reply_tail: nil
    },
    lists: [
      replies: [page_size: @page_size, dom_id: &"thread-reply-#{&1.id}"]
    ]

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:reply_arrived, item}}, socket) do
    [item] = place_after(socket, [put_locale(item)])

    {:ok,
     socket
     |> PaginatedList.insert(:replies, item)
     |> assign(reply_tail: item)}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.loaded_root_id == socket.assigns.root_id do
      {:ok, socket}
    else
      {:ok, socket |> assign(loaded_root_id: socket.assigns.root_id) |> load_thread()}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("thread_load_more", _params, socket) do
    {:noreply,
     PaginatedList.load(
       socket,
       :replies,
       fn opts ->
         page = fetch(socket, opts)
         %{page | items: place_after(socket, page.items)}
       end,
       &remember_tail/2
     )}
  end

  def handle_event("thread_reply", _params, socket) do
    send(self(), {:thread_reply, socket.assigns.kind, socket.assigns.root_id})
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.thread_panel
        id={@id}
        root={@root}
        replies={@streams.replies}
        state={@paginated.replies}
        target={@myself}
        nick_color_fn={@nick_color_fn}
        timestamp_format={@timestamp_format}
        timezone={@timezone}
        strip_formatting={@strip_formatting}
        viewer={@viewer}
      />
    </div>
    """
  end

  @spec load_thread(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp load_thread(socket) do
    case root_message(socket.assigns.kind, socket.assigns.root_id) do
      nil ->
        socket
        |> assign(root: nil)
        |> PaginatedList.reset(:replies, RetroHexChat.Page.empty())

      message ->
        page = fetch(socket, limit: @page_size)
        page = %{page | items: MessageGrouping.annotate_all(page.items, tz(socket))}

        socket
        |> assign(root: put_locale(row(socket.assigns.kind, message)), reply_tail: nil)
        |> PaginatedList.reset(:replies, page)
        |> remember_tail(page)
    end
  end

  # Replies arriving below the last one shown continue its run.
  @spec place_after(Phoenix.LiveView.Socket.t(), [map()]) :: [map()]
  defp place_after(socket, items) do
    MessageGrouping.annotate_after(List.wrap(socket.assigns.reply_tail), items, tz(socket))
  end

  defp remember_tail(socket, %{items: []}), do: socket
  defp remember_tail(socket, %{items: items}), do: assign(socket, reply_tail: List.last(items))

  defp tz(socket), do: socket.assigns[:timezone] || "Etc/UTC"

  @spec fetch(Phoenix.LiveView.Socket.t(), keyword()) :: RetroHexChat.Page.t()
  defp fetch(socket, opts) do
    kind = socket.assigns.kind

    case root_message(kind, socket.assigns.root_id) do
      nil ->
        RetroHexChat.Page.empty()

      message ->
        page =
          message
          |> Queries.thread_for(opts)
          |> RetroHexChat.Page.map(&(kind |> row(&1) |> without_quote()))

        %{page | items: put_locales(page.items)}
    end
  end

  # The flag beside each author, one lookup for the whole page.
  @spec put_locales([map()]) :: [map()]
  defp put_locales(items) do
    locales = items |> Enum.map(& &1.author) |> NickLocales.for_nicks()
    Enum.map(items, &StreamItem.put_locale(&1, Map.get(locales, &1.author)))
  end

  # The thread's first line, and a reply that arrives while the window is open:
  # the room's own row may already know its author's language; one that does
  # not is asked about on its own.
  @spec put_locale(map()) :: map()
  defp put_locale(%{locale: _locale} = item), do: item

  defp put_locale(item),
    do: StreamItem.put_locale(item, NickLocales.for_nick(item.author))

  defp root_message(_kind, nil), do: nil
  defp root_message(:message, id), do: Queries.get_message(id)
  defp root_message(:private_message, id), do: Queries.get_private_message(id)

  defp row(:message, message), do: StreamItem.from_message(message)
  defp row(:private_message, pm), do: StreamItem.from_private_message(pm)

  @doc """
  A row as this window draws it: the same row, without its quote block.

  Every line here answers the line at the top of the window, so the quote each
  one carries would repeat that same sentence once per reply. The window is the
  quote; inside it the rows are just what people said.
  """
  @spec without_quote(map()) :: map()
  def without_quote(item),
    do: Map.drop(item, [:reply_to_id, :reply_to_author, :reply_to_preview])
end
