defmodule RetroHexChatWeb.Components.URLCatcherWindow do
  @moduledoc """
  98.css styled URL Catcher window.
  Displays URLs captured from chat messages with sortable columns,
  channel filtering, and URL search.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, required: true
  attr :entries, :list, required: true
  attr :sort_column, :atom, required: true
  attr :sort_direction, :atom, required: true
  attr :filter_channel, :string, default: nil
  attr :search_query, :string, required: true
  attr :channels, :list, required: true
  attr :entry_count, :integer, required: true
  attr :timezone, :string, default: "Etc/UTC"

  @spec url_catcher_window(map()) :: Phoenix.LiveView.Rendered.t()
  def url_catcher_window(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="url-catcher-overlay"
    >
      <div
        data-testid="url-catcher-window"
        class="window u-flex-col url-catcher-window"
      >
        <div class="title-bar">
          <Icons.icon_dialog_url class="title-bar-icon" />
          <div class="title-bar-text">URL Catcher</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="toggle_url_catcher"></button>
          </div>
        </div>
        <div class="window-body u-p-4 u-flex-col u-flex-1 u-overflow-hidden">
          <%!-- Filter / Search toolbar --%>
          <div class="u-flex u-gap-8 u-mb-4 u-items-center u-text-sm">
            <label for="url-catcher-filter" class="u-text-nowrap">Filter:</label>
            <select
              id="url-catcher-filter"
              name="channel"
              phx-change="url_catcher_filter"
              data-testid="url-catcher-filter"
              class="u-text-sm u-min-w-120"
            >
              <option value="" selected={is_nil(@filter_channel)}>All Channels</option>
              <option
                :for={channel <- @channels}
                value={channel}
                selected={@filter_channel == channel}
              >
                {channel}
              </option>
            </select>
            <label for="url-catcher-search" class="u-text-nowrap">Search:</label>
            <input
              type="text"
              id="url-catcher-search"
              name="query"
              value={@search_query}
              phx-change="url_catcher_search"
              phx-debounce="300"
              placeholder="Search URLs..."
              autocomplete="off"
              data-testid="url-catcher-search"
              class="u-text-sm u-flex-1"
            />
          </div>
          <%!-- Table --%>
          <div
            id="url-catcher-table"
            phx-hook="URLCatcherHook"
            class="sunken-panel u-flex-1 u-overflow-y-auto"
          >
            <table
              class="table-standard"
              data-testid="url-catcher-table"
            >
              <thead>
                <tr class="u-sticky-top">
                  <th
                    class="u-cursor-pointer u-select-none"
                    phx-click="url_catcher_sort"
                    phx-value-column="url"
                    data-testid="url-catcher-sort-url"
                  >
                    URL {sort_indicator(@sort_column, @sort_direction, :url)}
                  </th>
                  <th
                    class="u-cursor-pointer u-select-none url-col-90"
                    phx-click="url_catcher_sort"
                    phx-value-column="source"
                    data-testid="url-catcher-sort-channel"
                  >
                    Channel {sort_indicator(@sort_column, @sort_direction, :source)}
                  </th>
                  <th
                    class="u-cursor-pointer u-select-none url-col-90"
                    phx-click="url_catcher_sort"
                    phx-value-column="posted_by"
                    data-testid="url-catcher-sort-posted-by"
                  >
                    Posted By {sort_indicator(@sort_column, @sort_direction, :posted_by)}
                  </th>
                  <th
                    class="u-cursor-pointer u-select-none url-col-actions"
                    phx-click="url_catcher_sort"
                    phx-value-column="timestamp"
                    data-testid="url-catcher-sort-time"
                  >
                    Time {sort_indicator(@sort_column, @sort_direction, :timestamp)}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={entry <- @entries}
                  data-url={entry.url}
                  data-testid={"url-catcher-entry-#{entry.id}"}
                  class="u-cursor-pointer"
                >
                  <td
                    class="table-cell--ellipsis url-cell-url"
                    title={entry.url}
                  >
                    {truncate_url(entry.url)}
                    <span
                      :if={entry.preview_title}
                      class="chat-link-preview"
                      data-testid="url-catcher-preview"
                    >
                      {entry.preview_title}
                    </span>
                  </td>
                  <td class="table-cell--nowrap">{entry.source}</td>
                  <td class="table-cell--nowrap">{entry.posted_by}</td>
                  <td class="table-cell--nowrap">{format_time(entry.timestamp, @timezone)}</td>
                </tr>
                <tr :if={@entries == []}>
                  <td colspan="4" class="table-empty" data-testid="url-catcher-empty">
                    <div
                      class="empty-state url-catcher-empty-state"
                      data-testid="url-catcher-empty-state"
                    >
                      <p>No URLs captured.</p>
                      <p>URLs mentioned in chat will appear here.</p>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <%!-- Status bar --%>
        <div class="status-bar" data-testid="url-catcher-status">
          <p class="status-bar-field">
            {status_text(@entry_count)}
          </p>
        </div>
      </div>
    </div>
    """
  end

  @spec sort_indicator(atom(), atom(), atom()) :: String.t()
  defp sort_indicator(active_column, direction, column) when active_column == column do
    if direction == :asc, do: "\u25B2", else: "\u25BC"
  end

  defp sort_indicator(_active_column, _direction, _column), do: ""

  @spec format_time(DateTime.t(), String.t()) :: String.t()
  defp format_time(%DateTime{} = dt, timezone) do
    dt |> RetroHexChatWeb.Timezone.shift(timezone) |> Calendar.strftime("%H:%M")
  end

  @spec truncate_url(String.t(), non_neg_integer()) :: String.t()
  defp truncate_url(url, max \\ 60) do
    if String.length(url) > max do
      String.slice(url, 0, max) <> "..."
    else
      url
    end
  end

  @spec status_text(integer()) :: String.t()
  defp status_text(0), do: "No URLs captured"
  defp status_text(1), do: "1 URL captured"
  defp status_text(count), do: "#{count} URLs captured"
end
