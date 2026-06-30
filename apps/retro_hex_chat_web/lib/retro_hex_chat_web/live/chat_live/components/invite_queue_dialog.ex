defmodule RetroHexChatWeb.ChatLive.Components.InviteQueueDialog do
  @moduledoc """
  Stateful island for the channel-invite notification queue. Renders the stack of
  pending invites and routes the Join/Ignore clicks to itself (`@myself`), bubbling
  the channel up via `send(self(), {:invite_accept | :invite_ignore, channel})`.

  Unlike the kick queue (`KickQueueDialog`), the queue itself is NOT owned here: it
  stays parent-owned as `pending_invites` because it is the Escape-priority
  read-model (`keyboard_events` dismisses the topmost invite before any other
  dialog) and the per-invite expiration timers fire into the parent LiveView
  process's `handle_info` (a LiveComponent has no `handle_info`). So this component
  is the render-model only: it receives the queue as passthrough (`invites`) and is
  isolated from the parent hot-path by change-tracking — the invite stack no longer
  re-renders on every chat message. The accept/ignore resolution (cancel the timer,
  drop the invite, join + status line) runs on the parent (`InviteEvents.accept/2` /
  `ignore/2`), which owns both the list and the session/stream effects (§1d).
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.InviteDialog

  @id "invite-queue-dialog"

  @doc "Stable DOM/component id used by the parent for `<.live_component>` mounting."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: {:ok, assign(socket, id: @id, invites: [])}

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("invite_accept", %{"channel" => channel}, socket) do
    send(self(), {:invite_accept, channel})
    {:noreply, socket}
  end

  def handle_event("invite_ignore", %{"channel" => channel}, socket) do
    send(self(), {:invite_ignore, channel})
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.invite_dialog
        id="invite-dialog"
        show={@invites != []}
        invites={@invites}
        on_accept={JS.push("invite_accept", target: @myself)}
        on_ignore={JS.push("invite_ignore", target: @myself)}
      />
    </div>
    """
  end
end
