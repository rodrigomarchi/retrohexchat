defmodule RetroHexChatWeb.ChatLive.SearchEvents do
  @moduledoc """
  Handles the search-bar events (`search_input`, `search_next`, `toggle_search`,
  …) on the chat LiveView and forwards them to the
  `RetroHexChatWeb.ChatLive.Components.SearchBar` component via `send_update/2`,
  which holds the search bar's content state (query, filters, results).

  The parent keeps `search_visible` because the Escape-dismissal map and overlay
  stacking in `KeyboardEvents` coordinate over parent assigns. This adapter is the
  intended end-state, not a temporary shim: `toggle_search`/`close_search` must set
  that parent flag, and `search_highlight_count` arrives from the `SearchHighlightHook`
  as a root `pushEvent`, so both genuinely belong on the LiveView and fan out to the
  component via `send_update`.

  Attached as `attach_hook(:search_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChatWeb.ChatLive.Components.SearchBar

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt | :cont, Phoenix.LiveView.Socket.t()}
  def handle_event("toggle_search", _params, socket) do
    if socket.assigns.search_visible do
      {:halt, close(socket)}
    else
      {:halt, open(socket)}
    end
  end

  def handle_event("close_search", _params, socket) do
    {:halt, close(socket)}
  end

  def handle_event("search_input", %{"query" => query}, socket) do
    {:halt, update_search(socket, {:input, query})}
  end

  def handle_event("search_next", _params, socket) do
    {:halt, update_search(socket, :next)}
  end

  def handle_event("search_prev", _params, socket) do
    {:halt, update_search(socket, :prev)}
  end

  def handle_event("search_navigate", %{"key" => key}, socket) do
    {:halt, update_search(socket, {:navigate, key})}
  end

  def handle_event("search_navigate", _params, socket) do
    {:halt, socket}
  end

  def handle_event("search_toggle_filter", %{"filter" => filter}, socket) do
    {:halt, update_search(socket, {:toggle_filter, filter})}
  end

  def handle_event("search_highlight_count", %{"count" => count} = params, socket) do
    {:halt, update_search(socket, {:highlight_count, count, params["error"]})}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # -- Helpers ---------------------------------------------------------------

  @doc """
  Opens the search bar: sets parent `search_visible` and tells the component to
  restore the last query. Also called from `KeyboardEvents` and `MenuToolbarEvents`.
  """
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    socket
    |> close_mobile_navigation_panels()
    |> assign(search_visible: true)
    |> update_search(:open)
  end

  @doc """
  Closes the search bar: clears parent `search_visible` and tells the component to
  save the last query, clear results and drop DOM highlights. Also called from the
  Escape-dismissal map and channel switch.
  """
  @spec close(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def close(socket) do
    socket
    |> assign(search_visible: false)
    |> update_search(:close)
  end

  @spec update_search(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  defp update_search(socket, action) do
    send_update(SearchBar, id: SearchBar.id(), action: action)
    socket
  end

  defp close_mobile_navigation_panels(%{assigns: %{mobile_viewport: true}} = socket) do
    assign(socket, show_conversations: false, show_nicklist: false)
  end

  defp close_mobile_navigation_panels(socket), do: socket
end
