defmodule RetroHexChatWeb.ChatLive.Components.MentionsDialog do
  @moduledoc """
  Stateful island behind the Mentions window.

  The list is a saved search, not a table: "who said my name" is answered from
  the messages themselves, because storing it would mean deciding, as every
  line is written, whether it mentions each of the people who might read it.

  It loads on the first update rather than on a message after mount. A window
  that asks for its contents afterwards races the patch that put it on screen,
  and the reader sees an empty list blink into a full one.

  The first page is the only one it fetches on its own. Everything after comes
  from the reader reaching the bottom, so a window opened and ignored costs one
  query.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.MentionsDialog

  alias RetroHexChat.Chat.Search
  alias RetroHexChatWeb.ChatLive.Helpers.NickFlags
  alias RetroHexChatWeb.PaginatedList

  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "mentions-dialog",
    load: &load_first_page/1

  @page_size 30

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: @id,
       session: nil,
       timezone: "Etc/UTC",
       nick_color_fn: nil,
       loaded?: false,
       first_row: nil
     )
     |> PaginatedList.init(:mentions,
       page_size: @page_size,
       dom_id: &"mention-#{&1.id}"
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("mentions_load_more", _params, socket) do
    {:noreply, PaginatedList.load(socket, :mentions, &fetch(socket, &1))}
  end

  # Opening one is a conversation switch plus a scroll, and both of those belong
  # to the host: the island owns a list, not the chat around it.
  def handle_event("mentions_open", %{"channel" => channel, "message_id" => id}, socket) do
    send(self(), {:open_mention, channel, id})
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.mentions_panel
        id={@id}
        mentions={@streams.mentions}
        first_row={@first_row}
        state={@paginated.mentions}
        target={@myself}
        timezone={@timezone}
        nick_color_fn={@nick_color_fn}
      />
    </div>
    """
  end

  @spec load_first_page(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp load_first_page(socket),
    do: PaginatedList.load_first(socket, :mentions, &fetch(socket, &1))

  @spec fetch(Phoenix.LiveView.Socket.t(), keyword()) :: RetroHexChat.Page.t()
  defp fetch(socket, opts) do
    NickFlags.authored_page(
      socket.assigns.session,
      &Search.list_mentions(&1.nickname, &1.channels, opts)
    )
  end
end
