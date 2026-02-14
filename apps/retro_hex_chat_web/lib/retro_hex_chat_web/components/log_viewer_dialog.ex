defmodule RetroHexChatWeb.Components.LogViewerDialog do
  @moduledoc """
  Log Viewer dialog — Windows 98-style window for searching, browsing,
  and exporting chat history. Supports channel and PM logs with filters
  for date range, nickname, and text content.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.DisplayPreferences

  attr :visible, :boolean, default: false
  attr :filter, :map, default: nil
  attr :page, :map, default: nil
  attr :preferences, :map, default: nil
  attr :source_options, :list, default: []
  attr :loading, :boolean, default: false
  attr :exporting, :boolean, default: false
  attr :error, :string, default: nil
  attr :nick_color_fn, :any, default: nil

  @spec log_viewer_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def log_viewer_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="log-viewer-dialog"
    >
      <div class="window u-flex-col dialog-window--log-viewer">
        <div class="title-bar">
          <div class="title-bar-text">Log Viewer</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_log_viewer"></button>
          </div>
        </div>
        <div class="window-body u-flex-1 u-flex-col u-p-4 u-overflow-hidden">
          <%!-- Filter bar --%>
          <div class="u-flex-col u-gap-4 u-mb-4">
            <div class="u-flex u-gap-4 u-items-center">
              <label class="u-text-sm u-min-w-50">Source:</label>
              <select
                class="u-flex-1 u-text-sm"
                phx-change="log_set_source"
                name="source"
                data-testid="log-source-select"
              >
                <option value="">All sources</option>
                <optgroup :if={has_channels?(@source_options)} label="Channels">
                  <option
                    :for={opt <- channel_options(@source_options)}
                    value={opt.value}
                    selected={
                      @filter && @filter.source == opt.value && @filter.source_type == :channel
                    }
                  >
                    {opt.label}
                  </option>
                </optgroup>
                <optgroup :if={has_pms?(@source_options)} label="Private Messages">
                  <option
                    :for={opt <- pm_options(@source_options)}
                    value={"pm:" <> opt.value}
                    selected={@filter && @filter.source == opt.value && @filter.source_type == :pm}
                  >
                    {opt.label}
                  </option>
                </optgroup>
              </select>
              <label class="u-text-sm">From:</label>
              <input
                type="date"
                name="date"
                class="u-text-sm log-date-input"
                phx-change="log_set_date_from"
                value={@filter && @filter.date_from && Date.to_iso8601(@filter.date_from)}
                data-testid="log-date-from"
              />
              <label class="u-text-sm">To:</label>
              <input
                type="date"
                name="date"
                class="u-text-sm log-date-input"
                phx-change="log_set_date_to"
                value={@filter && @filter.date_to && Date.to_iso8601(@filter.date_to)}
                data-testid="log-date-to"
              />
            </div>
            <form phx-submit="log_search" class="u-flex u-gap-4 u-items-center">
              <label class="u-text-sm u-min-w-50">Nick:</label>
              <input
                type="text"
                name="nickname"
                placeholder="Filter by nickname..."
                class="u-text-sm log-nick-input"
                value={@filter && @filter.nickname}
                data-testid="log-nickname-input"
              />
              <label class="u-text-sm">Text:</label>
              <input
                type="text"
                name="text"
                placeholder="Search text..."
                class="u-flex-1 u-text-sm"
                value={@filter && @filter.text}
                data-testid="log-text-input"
              />
              <button
                type="submit"
                class="btn-sm"
                data-testid="log-search-btn"
              >
                Search
              </button>
              <button
                type="button"
                phx-click="log_refresh"
                class="btn-sm"
                data-testid="log-refresh-btn"
              >
                Refresh
              </button>
            </form>
            <div
              :if={@error}
              class="form-error u-p-4"
              data-testid="log-error"
            >
              {@error}
            </div>
          </div>
          <%!-- Results area --%>
          <div class="log-results-area" data-testid="log-results-area">
            <div :if={@loading} class="u-p-8 u-text-muted" data-testid="log-loading">
              Searching...
            </div>
            <div
              :if={!@loading && @page == nil}
              class="u-p-8 u-text-muted"
              data-testid="log-initial-state"
            >
              Select a source and click Search to view logs.
            </div>
            <div
              :if={!@loading && @page != nil && @page.entries == []}
              class="u-p-8 u-text-muted"
              data-testid="log-empty-state"
            >
              No results found — try broadening your search criteria.
            </div>
            <div :if={!@loading && @page != nil && @page.entries != []}>
              <div
                :for={entry <- visible_entries(@page.entries, @preferences)}
                class={
                  if Map.get(entry, :type) == "system",
                    do: "log-entry--system",
                    else: "log-entry--message"
                }
              >
                <span class="u-text-muted">
                  {format_entry_timestamp(entry, @preferences)}
                </span>
                {render_entry(entry, @nick_color_fn)}
              </div>
            </div>
          </div>
          <%!-- Bottom bar: pagination + preferences + export --%>
          <div class="u-flex u-gap-8 u-items-center u-mt-4 u-flex-wrap">
            <%!-- Pagination --%>
            <div
              :if={@page != nil && @page.total_pages > 0}
              class="u-flex u-gap-4 u-items-center"
            >
              <button
                type="button"
                phx-click="log_page"
                phx-value-page={@page.page - 1}
                disabled={@page.page <= 1}
                class="btn-sm"
                data-testid="log-prev-btn"
              >
                « Prev
              </button>
              <span class="u-text-sm" data-testid="log-page-indicator">
                Page {@page.page} of {@page.total_pages}
              </span>
              <button
                type="button"
                phx-click="log_page"
                phx-value-page={@page.page + 1}
                disabled={@page.page >= @page.total_pages}
                class="btn-sm"
                data-testid="log-next-btn"
              >
                Next »
              </button>
            </div>
            <%!-- Export --%>
            <div class="u-flex u-gap-4 u-items-center u-ml-auto">
              <span :if={@exporting} class="u-text-sm u-text-muted">Exporting...</span>
              <button
                type="button"
                phx-click="log_export"
                phx-value-format="txt"
                disabled={export_disabled?(@page)}
                class="btn-sm"
                data-testid="log-export-txt"
              >
                Export .txt
              </button>
              <button
                type="button"
                phx-click="log_export"
                phx-value-format="html"
                disabled={export_disabled?(@page)}
                class="btn-sm"
                data-testid="log-export-html"
              >
                Export .html
              </button>
            </div>
          </div>
          <%!-- Display preferences --%>
          <fieldset class="u-mt-4 u-py-2 u-px-4">
            <legend class="u-text-sm">Display Options</legend>
            <div class="u-flex u-gap-8 u-items-center u-flex-wrap u-text-sm">
              <label data-testid="log-toggle-joins">
                <input
                  type="checkbox"
                  checked={@preferences && @preferences.show_joins}
                  phx-click="log_toggle_event"
                  phx-value-event_type="show_joins"
                /> Joins
              </label>
              <label data-testid="log-toggle-parts">
                <input
                  type="checkbox"
                  checked={@preferences && @preferences.show_parts}
                  phx-click="log_toggle_event"
                  phx-value-event_type="show_parts"
                /> Parts
              </label>
              <label data-testid="log-toggle-kicks">
                <input
                  type="checkbox"
                  checked={@preferences && @preferences.show_kicks}
                  phx-click="log_toggle_event"
                  phx-value-event_type="show_kicks"
                /> Kicks
              </label>
              <label data-testid="log-toggle-modes">
                <input
                  type="checkbox"
                  checked={@preferences && @preferences.show_mode_changes}
                  phx-click="log_toggle_event"
                  phx-value-event_type="show_mode_changes"
                /> Modes
              </label>
              <label data-testid="log-toggle-topics">
                <input
                  type="checkbox"
                  checked={@preferences && @preferences.show_topic_changes}
                  phx-click="log_toggle_event"
                  phx-value-event_type="show_topic_changes"
                /> Topics
              </label>
              <span class="u-ml-8">Time:</span>
              <select
                name="format"
                phx-change="log_set_timestamp_format"
                class="u-text-sm"
                data-testid="log-timestamp-format"
              >
                <option
                  value="hh_mm"
                  selected={@preferences && @preferences.timestamp_format == :hh_mm}
                >
                  HH:MM
                </option>
                <option
                  value="hh_mm_ss"
                  selected={@preferences && @preferences.timestamp_format == :hh_mm_ss}
                >
                  HH:MM:SS
                </option>
                <option
                  value="dd_mm_hh_mm"
                  selected={@preferences && @preferences.timestamp_format == :dd_mm_hh_mm}
                >
                  DD/MM HH:MM
                </option>
              </select>
            </div>
          </fieldset>
        </div>
      </div>
    </div>
    """
  end

  # Private helpers

  defp has_channels?(options), do: Enum.any?(options, fn opt -> opt.type == :channel end)
  defp has_pms?(options), do: Enum.any?(options, fn opt -> opt.type == :pm end)

  defp channel_options(options), do: Enum.filter(options, fn opt -> opt.type == :channel end)
  defp pm_options(options), do: Enum.filter(options, fn opt -> opt.type == :pm end)

  defp visible_entries(entries, nil), do: entries

  defp visible_entries(entries, prefs) do
    Enum.filter(entries, fn entry ->
      type = Map.get(entry, :type, "message")
      content = Map.get(entry, :content, "")
      DisplayPreferences.visible_type?(prefs, type, content)
    end)
  end

  defp format_entry_timestamp(entry, prefs) do
    ts = Map.get(entry, :inserted_at)

    if ts && prefs do
      DisplayPreferences.format_timestamp(prefs, ts)
    else
      ""
    end
  end

  defp render_entry(entry, nick_color_fn) do
    type = Map.get(entry, :type, "message")
    content = Map.get(entry, :content, "")

    case type do
      "system" ->
        assigns = %{content: content}

        ~H"""
        <span>{" * "}{@content}</span>
        """

      "action" ->
        nick = get_nick(entry)
        color = nick_color(nick, nick_color_fn)
        assigns = %{nick: nick, content: content, color: color}

        ~H"""
        <span> * <span style={@color}>{@nick}</span> {@content}</span>
        """

      _ ->
        nick = get_nick(entry)
        color = nick_color(nick, nick_color_fn)
        assigns = %{nick: nick, content: content, color: color}

        ~H"""
        <span> &lt;<span style={@color}>{@nick}</span>&gt; {@content}</span>
        """
    end
  end

  defp get_nick(entry) do
    Map.get(entry, :author_nickname) || Map.get(entry, :sender_nickname, "")
  end

  defp nick_color(_nick, nil), do: nil

  defp nick_color(nick, color_fn) when is_function(color_fn, 1) do
    case color_fn.(nick) do
      nil -> nil
      color -> "color: #{color};"
    end
  end

  defp export_disabled?(nil), do: true
  defp export_disabled?(%{entries: []}), do: true
  defp export_disabled?(_), do: false
end
