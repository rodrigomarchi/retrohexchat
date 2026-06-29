defmodule RetroHexChatWeb.ChatLive.TipEvents do
  @moduledoc """
  Acknowledges the `tips_state_sync` telemetry from the ContextualTipsHook JS hook.

  Contextual tips are fully client-side: the hook owns the queue, dismissal and
  suppression preference (localStorage). The server keeps NO tip state — the old
  `tips_suppressed` assign was write-only (never read anywhere), so it was removed.
  The hook still fires the sync event, so we swallow it cleanly here (rather than
  let it fall through to the unrouted-event debug log). Re-introduce a server
  assign only if a server-side consumer of the suppression preference is added.

  Attached as `attach_hook(:tip_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def handle_event("tips_state_sync", _params, socket), do: {:halt, socket}

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
