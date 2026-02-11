defmodule RetroHexChatWeb.Components.URLCatcherWindow do
  @moduledoc """
  98.css styled URL Catcher window.
  Displays URLs captured from chat messages with sortable columns,
  channel filtering, and URL search.
  """
  use Phoenix.Component

  attr :visible, :boolean, required: true
  attr :entries, :list, required: true
  attr :sort_column, :atom, required: true
  attr :sort_direction, :atom, required: true
  attr :filter_channel, :string, default: nil
  attr :search_query, :string, required: true
  attr :channels, :list, required: true
  attr :entry_count, :integer, required: true

  @spec url_catcher_window(map()) :: Phoenix.LiveView.Rendered.t()
  def url_catcher_window(assigns) do
    ~H"""
    <div
      :if={@visible}
      data-testid="url-catcher-window"
      class="window"
      style="position: absolute; bottom: 40px; right: 10px; width: 500px; height: 350px; z-index: 150; display: flex; flex-direction: column;"
    >
      <div class="title-bar">
        <div class="title-bar-text">URL Catcher</div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="toggle_url_catcher"></button>
        </div>
      </div>
      <div
        class="window-body"
        style="padding: 4px; display: flex; flex-direction: column; flex: 1; overflow: hidden;"
      >
        <%!-- Filter / Search toolbar --%>
        <div style="display: flex; gap: 8px; margin-bottom: 4px; align-items: center; font-size: 11px;">
          <label for="url-catcher-filter" style="white-space: nowrap;">Filter:</label>
          <select
            id="url-catcher-filter"
            name="channel"
            phx-change="url_catcher_filter"
            data-testid="url-catcher-filter"
            style="font-size: 11px; min-width: 120px;"
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
          <label for="url-catcher-search" style="white-space: nowrap;">Search:</label>
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
            style="font-size: 11px; flex: 1;"
          />
        </div>
        <%!-- Table --%>
        <div
          id="url-catcher-table"
          phx-hook="URLCatcherHook"
          class="sunken-panel"
          style="flex: 1; overflow-y: auto;"
        >
          <table
            style="width: 100%; border-collapse: collapse; font-size: 11px;"
            data-testid="url-catcher-table"
          >
            <thead>
              <tr style="background: #c0c0c0; position: sticky; top: 0;">
                <th
                  style="text-align: left; padding: 2px 4px; cursor: pointer; user-select: none;"
                  phx-click="url_catcher_sort"
                  phx-value-column="url"
                  data-testid="url-catcher-sort-url"
                >
                  URL {sort_indicator(@sort_column, @sort_direction, :url)}
                </th>
                <th
                  style="text-align: left; padding: 2px 4px; cursor: pointer; user-select: none; width: 90px;"
                  phx-click="url_catcher_sort"
                  phx-value-column="source"
                  data-testid="url-catcher-sort-channel"
                >
                  Channel {sort_indicator(@sort_column, @sort_direction, :source)}
                </th>
                <th
                  style="text-align: left; padding: 2px 4px; cursor: pointer; user-select: none; width: 90px;"
                  phx-click="url_catcher_sort"
                  phx-value-column="posted_by"
                  data-testid="url-catcher-sort-posted-by"
                >
                  Posted By {sort_indicator(@sort_column, @sort_direction, :posted_by)}
                </th>
                <th
                  style="text-align: left; padding: 2px 4px; cursor: pointer; user-select: none; width: 60px;"
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
                style="cursor: pointer;"
              >
                <td
                  style="padding: 2px 4px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 0;"
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
                <td style="padding: 2px 4px; white-space: nowrap;">{entry.source}</td>
                <td style="padding: 2px 4px; white-space: nowrap;">{entry.posted_by}</td>
                <td style="padding: 2px 4px; white-space: nowrap;">{format_time(entry.timestamp)}</td>
              </tr>
              <tr :if={@entries == []}>
                <td
                  colspan="4"
                  style="text-align: center; padding: 8px; color: #808080; font-size: 11px;"
                  data-testid="url-catcher-empty"
                >
                  No URLs captured.
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
    """
  end

  @spec sort_indicator(atom(), atom(), atom()) :: String.t()
  defp sort_indicator(active_column, direction, column) when active_column == column do
    if direction == :asc, do: "\u25B2", else: "\u25BC"
  end

  defp sort_indicator(_active_column, _direction, _column), do: ""

  @spec format_time(DateTime.t()) :: String.t()
  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M")
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
