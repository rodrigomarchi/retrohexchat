defmodule RetroHexChatWeb.ChatLive.Components.PinnedDialog do
  @moduledoc """
  Stateful island behind the Pinned window.

  Shows what the channel on screen is keeping. It loads on the first update
  rather than on a message after mount: a window that asks for its contents
  afterwards races the patch that put it on screen, and the reader watches an
  empty list blink into a full one.

  Unpinning happens here because the list is here, but the permission does not:
  the button is drawn for somebody who looks like an operator, and the channel
  decides again when the unpin actually arrives. Drawing is a convenience;
  refusing is the channel's.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.PinnedDialog

  alias RetroHexChat.Channels.Pins
  alias RetroHexChatWeb.PaginatedList

  @id "pinned-dialog"
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
       channel: nil,
       can_unpin: false,
       timezone: "Etc/UTC",
       nick_color_fn: nil,
       loaded?: false
     )
     |> PaginatedList.init(:pins,
       page_size: @page_size,
       dom_id: &"pin-#{&1.message_id}"
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  # A channel switch is a different list, so it reloads; anything else that
  # re-renders the parent must not.
  def update(assigns, socket) do
    previous = socket.assigns.channel
    socket = assign(socket, assigns)

    if socket.assigns.loaded? and socket.assigns.channel == previous do
      {:ok, socket}
    else
      {:ok, socket |> assign(loaded?: true) |> load_first_page()}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("pinned_load_more", _params, socket) do
    {:noreply, PaginatedList.load(socket, :pins, &fetch(socket, &1))}
  end

  # Going to the line is a scroll in the conversation, which belongs to the
  # host: the island owns a list, not the chat around it.
  def handle_event("pinned_open", %{"message_id" => id}, socket) do
    send(self(), {:open_pinned, socket.assigns.channel, id})
    {:noreply, socket}
  end

  def handle_event("pinned_unpin", %{"message_id" => id}, socket) do
    send(self(), {:unpin_message, socket.assigns.channel, id})
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.pinned_panel
        id={@id}
        pins={@streams.pins}
        state={@paginated.pins}
        can_unpin={@can_unpin}
        target={@myself}
        timezone={@timezone}
        nick_color_fn={@nick_color_fn}
      />
    </div>
    """
  end

  @spec load_first_page(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp load_first_page(socket) do
    PaginatedList.reset(socket, :pins, fetch(socket, limit: @page_size))
  end

  @spec fetch(Phoenix.LiveView.Socket.t(), keyword()) :: RetroHexChat.Page.t()
  defp fetch(socket, opts) do
    case socket.assigns.channel do
      nil -> %RetroHexChat.Page{}
      channel -> Pins.list(channel, opts)
    end
  end
end
