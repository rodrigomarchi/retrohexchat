defmodule RetroHexChatWeb.ChatLive.Components.OpenTabConfirmDialog do
  @moduledoc """
  The confirmation that stands between a click and a second browser tab. Owns
  the pending destination while the dialog is open, and derives its own
  visibility from it — there is no separate `show` to fall out of step with the
  target it describes.

  `LinkEvents` on the parent opens it via `send_update/2` (`{:set, target}`),
  because the click arrives as a hook `pushEvent` and a hook in this application
  pushes to the root LiveView. Nothing here validates the target: the parent has
  already refused anything that is not `http`, `https` or a path of our own, and
  a second opinion in a component that cannot say no is worse than none.

  Open is handled locally and does nothing but clear: the button is a real
  anchor, so the browser has already opened the tab by the time this runs. Cancel
  clears and hands the keyboard back to the composer, which is where it was.

  This hosts `OpenTabConfirmHook` on its own mount element rather than on the
  desktop root. A hook's `pushEvent` stamps `data-phx-ref-lock` on its own
  element and subsequent patches land in a detached clone — mounting a
  click-intercepting hook on the shell would put that lock on the whole chat.
  The element is small and stable; the listener it binds is on `document`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.OpenTabConfirmDialog

  @id "open-tab-confirm-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: {:ok, assign(socket, id: @id, target: nil)}

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:set, target}}, socket), do: {:ok, assign(socket, target: target)}
  def update(%{action: :close}, socket), do: {:ok, assign(socket, target: nil)}
  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("open_tab_confirm_open", _params, socket) do
    {:noreply, assign(socket, target: nil)}
  end

  def handle_event("open_tab_confirm_cancel", _params, socket) do
    {:noreply, socket |> assign(target: nil) |> push_event("focus_input", %{})}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} phx-hook="OpenTabConfirmHook">
      <.open_tab_confirm_dialog
        id={@id}
        show={@target != nil}
        target={@target}
        on_open={open_command(@target, @myself)}
        on_cancel={JS.push("open_tab_confirm_cancel", target: @myself)}
      />
    </div>
    """
  end

  # Confirming is one or two pushes on the same anchor. The second is always the
  # clear; the first exists only for a door that was doing something besides
  # linking — the arcade's Start Game also tells the domain a game began, and
  # that call belongs on this click rather than on the one that only asked the
  # question. Cancelling never sends it, which is the whole point of holding it.
  @spec open_command(map() | nil, %Phoenix.LiveComponent.CID{}) :: Phoenix.LiveView.JS.t()
  defp open_command(%{event: event} = target, myself) when is_binary(event) and event != "" do
    event
    |> JS.push(value: Map.get(target, :params) || %{})
    |> JS.push("open_tab_confirm_open", target: myself)
  end

  defp open_command(_target, myself), do: JS.push("open_tab_confirm_open", target: myself)
end
