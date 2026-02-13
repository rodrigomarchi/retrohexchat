defmodule RetroHexChatWeb.ChatLive.UrlCatcherEvents do
  @moduledoc """
  Handle events for the URL Catcher window.

  Covers: toggle_url_catcher, url_catcher_sort, url_catcher_filter, url_catcher_search.

  Attached as `attach_hook(:url_catcher_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  def handle_event("toggle_url_catcher", _params, socket) do
    {:halt, assign(socket, show_url_catcher: !socket.assigns.show_url_catcher)}
  end

  def handle_event("url_catcher_sort", %{"column" => column}, socket) do
    col = String.to_existing_atom(column)

    direction =
      if socket.assigns.url_catcher_sort_column == col,
        do: toggle_direction(socket.assigns.url_catcher_sort_direction),
        else: :asc

    {:halt, assign(socket, url_catcher_sort_column: col, url_catcher_sort_direction: direction)}
  end

  def handle_event("url_catcher_filter", %{"channel" => ""}, socket) do
    {:halt, assign(socket, url_catcher_filter_channel: nil)}
  end

  def handle_event("url_catcher_filter", %{"channel" => channel}, socket) do
    {:halt, assign(socket, url_catcher_filter_channel: channel)}
  end

  def handle_event("url_catcher_search", %{"query" => query}, socket) do
    {:halt, assign(socket, url_catcher_search_query: query)}
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private ────────────────────────────────────────────────

  defp toggle_direction(:asc), do: :desc
  defp toggle_direction(:desc), do: :asc
end
