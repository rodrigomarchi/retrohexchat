defmodule RetroHexChatWeb.ChatLive.Components.SavedDialog do
  @moduledoc """
  Stateful island behind the Saved Messages window.

  Shows what this person kept, newest first, across every conversation they
  were in. It loads on the first update rather than on a message after mount: a
  window that asks for its contents afterwards races the patch that put it on
  screen, and the reader watches an empty list blink into a full one.

  Removing happens here because the list is here. Going to the line does not:
  that is a conversation switch plus a scroll, and both belong to the host —
  the island owns a list, not the chat around it.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.SavedDialog

  alias RetroHexChat.Chat.SavedMessages
  alias RetroHexChatWeb.PaginatedList

  @id "saved-dialog"
  @page_size 25

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: @id,
       nickname: nil,
       timezone: "Etc/UTC",
       nick_color_fn: nil,
       loaded?: false,
       first_row: nil
     )
     |> PaginatedList.init(:saved,
       page_size: @page_size,
       dom_id: &"saved-#{&1.id}"
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  # `reload: true` is how the host says the list changed under the window — a
  # line saved or dropped from the conversation while this was open.
  def update(assigns, socket) do
    reload? = Map.get(assigns, :reload, false)
    socket = socket |> assign(Map.delete(assigns, :reload))

    if socket.assigns.loaded? and not reload? do
      {:ok, socket}
    else
      {:ok, socket |> assign(loaded?: true) |> load_first_page()}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("saved_load_more", _params, socket) do
    {:noreply, PaginatedList.load(socket, :saved, &fetch(socket, &1))}
  end

  # The row carries where it came from, so nothing here has to keep a copy of
  # a list the stream already owns.
  def handle_event("saved_open", params, socket) do
    send(
      self(),
      {:open_saved,
       %{
         channel: params["channel"],
         counterpart: params["counterpart"],
         message_id: to_integer(params["message_id"])
       }}
    )

    {:noreply, socket}
  end

  def handle_event("saved_remove", %{"saved_id" => id}, socket) do
    send(self(), {:remove_saved, to_integer(id)})
    {:noreply, socket}
  end

  def handle_event("saved_note", %{"saved_id" => id, "note" => note}, socket) do
    send(self(), {:set_saved_note, to_integer(id), note})
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.saved_panel
        id={@id}
        entries={@streams.saved}
        first_row={@first_row}
        state={@paginated.saved}
        target={@myself}
        timezone={@timezone}
        nick_color_fn={@nick_color_fn}
      />
    </div>
    """
  end

  @spec load_first_page(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp load_first_page(socket) do
    page = fetch(socket, limit: @page_size)

    socket
    |> assign(:first_row, List.first(page.items))
    |> PaginatedList.reset(:saved, page)
  end

  @spec fetch(Phoenix.LiveView.Socket.t(), keyword()) :: RetroHexChat.Page.t()
  defp fetch(socket, opts) do
    case socket.assigns.nickname do
      nil -> %RetroHexChat.Page{}
      nickname -> SavedMessages.list(nickname, opts)
    end
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
