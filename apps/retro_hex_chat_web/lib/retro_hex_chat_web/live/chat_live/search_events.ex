defmodule RetroHexChatWeb.ChatLive.SearchEvents do
  @moduledoc """
  Handle events for the in-channel search feature.

  Covers: toggle_search, search_input, search_next, search_prev, close_search.

  Attached as `attach_hook(:search_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Chat.Search

  def handle_event("toggle_search", _params, socket) do
    visible = !socket.assigns.search_visible

    if visible do
      {:halt, assign(socket, search_visible: true)}
    else
      {:halt, clear_search_state(socket)}
    end
  end

  def handle_event("search_input", %{"query" => query}, socket) do
    {:halt, do_search(socket, query)}
  end

  def handle_event("search_next", _params, socket) do
    %{search_current_index: idx, search_result_count: count} = socket.assigns

    if count > 0 do
      new_index = if idx >= count, do: 1, else: idx + 1
      {:halt, assign(socket, search_current_index: new_index)}
    else
      {:halt, socket}
    end
  end

  def handle_event("search_prev", _params, socket) do
    %{search_current_index: idx, search_result_count: count} = socket.assigns

    if count > 0 do
      new_index = if idx <= 1, do: count, else: idx - 1
      {:halt, assign(socket, search_current_index: new_index)}
    else
      {:halt, socket}
    end
  end

  def handle_event("close_search", _params, socket) do
    {:halt, clear_search_state(socket)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # -- Private helpers -------------------------------------------------------

  defp do_search(socket, "") do
    clear_search_state(socket)
  end

  defp do_search(socket, query) do
    channel = socket.assigns.session.active_channel

    if channel do
      count = Search.count_matches(channel, query)
      results = Search.search_messages(channel, query)

      assign(socket,
        search_query: query,
        search_results: results,
        search_result_count: count,
        search_current_index: min(1, count)
      )
    else
      assign(socket, search_query: query, search_results: [], search_result_count: 0)
    end
  end

  defp clear_search_state(socket) do
    assign(socket,
      search_visible: false,
      search_query: "",
      search_results: [],
      search_result_count: 0,
      search_current_index: 0
    )
  end
end
