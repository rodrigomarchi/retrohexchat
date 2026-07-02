defmodule RetroHexChatWeb.ChatLive.UrlCatcherEvents do
  @moduledoc """
  Route the URL Catcher menu/toolbar action to its desktop window.

  The window is always mounted and the window manager owns open/close
  client-side, so the action just pushes a `window_command` to open/focus it —
  re-invoking focuses the existing window. The capture log
  (`url_catcher_entries`) stays in the parent (appended from messages + the
  context menu) and flows into the window island as passthrough; the view state
  (sort/filter/search) lives in `Components.UrlCatcherDialog`.

  Attached as `attach_hook(:url_catcher_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  def handle_event("toggle_url_catcher", _params, socket) do
    {:halt, push_event(socket, "window_command", %{action: "open", id: "url-catcher"})}
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
