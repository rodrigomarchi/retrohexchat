defmodule RetroHexChatWeb.ChatLive.Components.UrlCatcherDialog do
  @moduledoc """
  The URL Catcher window. The parent keeps `show_url_catcher` (read by the
  Escape-dismissal map) and passes it as `visible`, plus the running capture log
  `entries` (appended from messages and the context menu) and the `timezone`.

  Owns the view state — `filter_channel`, `search_query`, `sort_column`,
  `sort_direction` — and filters, searches and sorts `entries` for display. These
  are pure-UI events handled component-locally (`@myself`). The view state
  persists between opens (closing does not reset it), so there is no `:reset`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.UrlCatcher

  alias RetroHexChat.Chat.CapturedURL

  @id "url-catcher-dialog"

  @doc "Stable DOM/component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       visible: false,
       entries: [],
       timezone: nil,
       filter_channel: nil,
       search_query: "",
       sort_column: :timestamp,
       sort_direction: :desc
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok,
     assign(socket,
       visible: Map.get(assigns, :visible, socket.assigns.visible),
       entries: Map.get(assigns, :entries, socket.assigns.entries),
       timezone: Map.get(assigns, :timezone, socket.assigns.timezone)
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("url_catcher_sort", %{"column" => column}, socket) do
    col = String.to_existing_atom(column)

    direction =
      if socket.assigns.sort_column == col,
        do: toggle_direction(socket.assigns.sort_direction),
        else: :asc

    {:noreply, assign(socket, sort_column: col, sort_direction: direction)}
  end

  def handle_event("url_catcher_filter", %{"channel" => ""}, socket) do
    {:noreply, assign(socket, filter_channel: nil)}
  end

  def handle_event("url_catcher_filter", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, filter_channel: channel)}
  end

  def handle_event("url_catcher_search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assign(assigns,
        filtered: filtered_entries(assigns),
        channels: channels(assigns.entries)
      )

    ~H"""
    <div id={"#{@id}-mount"}>
      <.url_catcher
        id={@id}
        show={@visible}
        entries={@filtered}
        sort_column={@sort_column}
        sort_direction={@sort_direction}
        filter_channel={@filter_channel}
        search_query={@search_query}
        channels={@channels}
        entry_count={length(@entries)}
        timezone={@timezone}
        on_sort={JS.push("url_catcher_sort", target: @myself)}
        on_filter={JS.push("url_catcher_filter", target: @myself)}
        on_search={JS.push("url_catcher_search", target: @myself)}
        on_close="close_url_catcher"
      />
    </div>
    """
  end

  @spec filtered_entries(map()) :: [map()]
  defp filtered_entries(assigns) do
    assigns.entries
    |> CapturedURL.filter_by_source(assigns.filter_channel)
    |> CapturedURL.filter_by_url(assigns.search_query)
    |> CapturedURL.sort_by(assigns.sort_column, assigns.sort_direction)
  end

  @spec channels([map()]) :: [String.t()]
  defp channels(entries) do
    entries
    |> Enum.map(& &1.source)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec toggle_direction(:asc | :desc) :: :asc | :desc
  defp toggle_direction(:asc), do: :desc
  defp toggle_direction(:desc), do: :asc
end
