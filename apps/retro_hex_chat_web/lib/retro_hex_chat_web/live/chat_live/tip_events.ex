defmodule RetroHexChatWeb.ChatLive.TipEvents do
  @moduledoc """
  Handle contextual tips sync events.

  Receives `tips_state_sync` from the ContextualTipsHook JS hook
  to keep the server-side assigns in sync with client-side
  localStorage state.

  Attached as `attach_hook(:tip_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 3]

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def handle_event("tips_state_sync", %{"suppressed" => suppressed}, socket) do
    {:halt, assign(socket, :tips_suppressed, suppressed)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
