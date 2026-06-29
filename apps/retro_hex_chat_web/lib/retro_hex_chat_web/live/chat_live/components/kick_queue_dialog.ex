defmodule RetroHexChatWeb.ChatLive.Components.KickQueueDialog do
  @moduledoc """
  The kick-notification queue. This is a PubSub-driven notification queue rather
  than an Escape-managed dialog — the component owns the whole `queue` and derives
  its own visibility (shown while the queue is non-empty).

  The parent's channel-state PubSub handler enqueues via `send_update/2`
  (`{:enqueue, kick_event}`) when the local user is kicked; the OK/dismiss button
  is handled component-locally (`@myself`), dequeuing the head. The parent handles
  the channel part, sound and system message around the enqueue.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.KickDialog

  @id "kick-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: {:ok, assign(socket, id: @id, queue: [])}

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:enqueue, kick_event}}, socket) do
    {:ok, assign(socket, queue: socket.assigns.queue ++ [kick_event])}
  end

  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("kick_dialog_dismiss", _params, socket) do
    {:noreply, assign(socket, queue: dequeue(socket.assigns.queue))}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.kick_dialog
        id={@id}
        show={@queue != []}
        kick_info={List.first(@queue)}
        on_dismiss={JS.push("kick_dialog_dismiss", target: @myself)}
      />
    </div>
    """
  end

  @spec dequeue([map()]) :: [map()]
  defp dequeue([_ | rest]), do: rest
  defp dequeue([]), do: []
end
