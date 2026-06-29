defmodule RetroHexChatWeb.ChatLive.UrlCatcherEvents do
  @moduledoc """
  Handle window open/close for the URL Catcher.

  The view state (sort/filter/search) lives in the `Components.UrlCatcherDialog`
  LiveComponent; this module only flips `show_url_catcher` (kept in the parent for
  the Escape-dismissal map). The capture log (`url_catcher_entries`) also stays in
  the parent (appended from messages + the context menu) and is passed to the
  component as passthrough.

  Attached as `attach_hook(:url_catcher_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  def handle_event("toggle_url_catcher", _params, socket) do
    {:halt, assign(socket, show_url_catcher: !socket.assigns.show_url_catcher)}
  end

  def handle_event("close_url_catcher", _params, socket) do
    {:halt, assign(socket, show_url_catcher: false)}
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
