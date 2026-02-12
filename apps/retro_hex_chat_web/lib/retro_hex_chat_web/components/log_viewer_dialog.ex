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
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
      data-testid="log-viewer-dialog"
    >
      <div class="window" style="width: 750px; height: 550px; display: flex; flex-direction: column;">
        <div class="title-bar">
          <div class="title-bar-text">Log Viewer</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_log_viewer"></button>
          </div>
        </div>
        <div
          class="window-body"
          style="flex: 1; display: flex; flex-direction: column; padding: 4px; overflow: hidden;"
        >
          <%!-- Filter bar --%>
          <div style="display: flex; flex-direction: column; gap: 4px; margin-bottom: 4px;">
            <div style="display: flex; gap: 4px; align-items: center;">
              <label style="font-size: 11px; min-width: 50px;">Source:</label>
              <select
                style="flex: 1; font-size: 11px;"
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
              <label style="font-size: 11px;">From:</label>
              <input
                type="date"
                name="date"
                style="font-size: 11px; width: 130px;"
                phx-change="log_set_date_from"
                value={@filter && @filter.date_from && Date.to_iso8601(@filter.date_from)}
                data-testid="log-date-from"
              />
              <label style="font-size: 11px;">To:</label>
              <input
                type="date"
                name="date"
                style="font-size: 11px; width: 130px;"
                phx-change="log_set_date_to"
                value={@filter && @filter.date_to && Date.to_iso8601(@filter.date_to)}
                data-testid="log-date-to"
              />
            </div>
            <form phx-submit="log_search" style="display: flex; gap: 4px; align-items: center;">
              <label style="font-size: 11px; min-width: 50px;">Nick:</label>
              <input
                type="text"
                name="nickname"
                placeholder="Filter by nickname..."
                style="width: 120px; font-size: 11px;"
                value={@filter && @filter.nickname}
                data-testid="log-nickname-input"
              />
              <label style="font-size: 11px;">Text:</label>
              <input
                type="text"
                name="text"
                placeholder="Search text..."
                style="flex: 1; font-size: 11px;"
                value={@filter && @filter.text}
                data-testid="log-text-input"
              />
              <button
                type="submit"
                style="font-size: 11px; padding: 1px 8px;"
                data-testid="log-search-btn"
              >
                Search
              </button>
              <button
                type="button"
                phx-click="log_refresh"
                style="font-size: 11px; padding: 1px 8px;"
                data-testid="log-refresh-btn"
              >
                Refresh
              </button>
            </form>
            <div
              :if={@error}
              style="color: red; font-size: 11px; padding: 2px 4px;"
              data-testid="log-error"
            >
              {@error}
            </div>
          </div>
          <%!-- Results area --%>
          <div
            style="flex: 1; overflow-y: auto; border: 1px solid #808080; background: #fff; padding: 2px; font-family: 'Courier New', Courier, monospace; font-size: 11px;"
            data-testid="log-results-area"
          >
            <div :if={@loading} style="padding: 8px; color: #808080;" data-testid="log-loading">
              Searching...
            </div>
            <div
              :if={!@loading && @page == nil}
              style="padding: 8px; color: #808080;"
              data-testid="log-initial-state"
            >
              Select a source and click Search to view logs.
            </div>
            <div
              :if={!@loading && @page != nil && @page.entries == []}
              style="padding: 8px; color: #808080;"
              data-testid="log-empty-state"
            >
              No results found — try broadening your search criteria.
            </div>
            <div :if={!@loading && @page != nil && @page.entries != []}>
              <div
                :for={entry <- visible_entries(@page.entries, @preferences)}
                style={entry_style(entry)}
              >
                <span style="color: #808080;">
                  {format_entry_timestamp(entry, @preferences)}
                </span>
                {render_entry(entry, @nick_color_fn)}
              </div>
            </div>
          </div>
          <%!-- Bottom bar: pagination + preferences + export --%>
          <div style="display: flex; gap: 8px; align-items: center; margin-top: 4px; flex-wrap: wrap;">
            <%!-- Pagination --%>
            <div
              :if={@page != nil && @page.total_pages > 0}
              style="display: flex; gap: 4px; align-items: center;"
            >
              <button
                type="button"
                phx-click="log_page"
                phx-value-page={@page.page - 1}
                disabled={@page.page <= 1}
                style="font-size: 11px; padding: 1px 6px;"
                data-testid="log-prev-btn"
              >
                « Prev
              </button>
              <span style="font-size: 11px;" data-testid="log-page-indicator">
                Page {@page.page} of {@page.total_pages}
              </span>
              <button
                type="button"
                phx-click="log_page"
                phx-value-page={@page.page + 1}
                disabled={@page.page >= @page.total_pages}
                style="font-size: 11px; padding: 1px 6px;"
                data-testid="log-next-btn"
              >
                Next »
              </button>
            </div>
            <%!-- Export --%>
            <div style="display: flex; gap: 4px; align-items: center; margin-left: auto;">
              <span :if={@exporting} style="font-size: 11px; color: #808080;">Exporting...</span>
              <button
                type="button"
                phx-click="log_export"
                phx-value-format="txt"
                disabled={export_disabled?(@page)}
                style="font-size: 11px; padding: 1px 8px;"
                data-testid="log-export-txt"
              >
                Export .txt
              </button>
              <button
                type="button"
                phx-click="log_export"
                phx-value-format="html"
                disabled={export_disabled?(@page)}
                style="font-size: 11px; padding: 1px 8px;"
                data-testid="log-export-html"
              >
                Export .html
              </button>
            </div>
          </div>
          <%!-- Display preferences --%>
          <fieldset style="margin-top: 4px; padding: 2px 4px;">
            <legend style="font-size: 11px;">Display Options</legend>
            <div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap; font-size: 11px;">
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
              <span style="margin-left: 8px;">Time:</span>
              <select
                name="format"
                phx-change="log_set_timestamp_format"
                style="font-size: 11px;"
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

  defp entry_style(entry) do
    if Map.get(entry, :type) == "system" do
      "padding: 1px 0; color: #808080; font-style: italic;"
    else
      "padding: 1px 0;"
    end
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
