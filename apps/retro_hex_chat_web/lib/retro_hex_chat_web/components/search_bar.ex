defmodule RetroHexChatWeb.Components.SearchBar do
  @moduledoc """
  Win98-styled search dialog with text input, Find Next/Prev buttons,
  arrow key navigation, error display, and an X of Y result counter.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :query, :string, default: ""
  attr :result_count, :integer, default: 0
  attr :current_index, :integer, default: 0
  attr :error, :string, default: nil
  attr :case_sensitive, :boolean, default: false
  attr :regex, :boolean, default: false
  attr :my_mentions, :boolean, default: false
  attr :history, :boolean, default: false

  @spec search_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def search_bar(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="search-bar window"
      style="position: absolute; top: 4px; right: 4px; z-index: 100; min-width: 320px;"
    >
      <div class="title-bar" style="padding: 2px 4px;">
        <div class="title-bar-text" style="font-size: 11px;">Find</div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="close_search"></button>
        </div>
      </div>
      <div class="window-body" style="padding: 4px;">
        <div style="display: flex; gap: 4px; align-items: center;">
          <form phx-change="search_input" phx-submit="search_next" style="display: contents;">
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Find..."
              autocomplete="off"
              style="flex: 1; font-size: 11px;"
              phx-debounce="300"
              phx-keydown="search_navigate"
            />
          </form>
          <span :if={@error} class="search-error">{@error}</span>
          <span
            :if={!@error}
            style="font-size: 11px; white-space: nowrap; min-width: 50px; text-align: center;"
          >
            {search_counter(@current_index, @result_count)}
          </span>
          <button
            type="button"
            phx-click="search_prev"
            disabled={@result_count == 0}
            style="font-size: 11px; padding: 1px 6px;"
          >
            Prev
          </button>
          <button
            type="button"
            phx-click="search_next"
            disabled={@result_count == 0}
            style="font-size: 11px; padding: 1px 6px;"
          >
            Next
          </button>
        </div>
        <div
          class="search-filters"
          style="display: flex; gap: 8px; margin-top: 4px; font-size: 11px;"
        >
          <label style="display: flex; align-items: center; gap: 2px;">
            <input
              type="checkbox"
              checked={@case_sensitive}
              phx-click="search_toggle_filter"
              phx-value-filter="case_sensitive"
            /> Case
          </label>
          <label style="display: flex; align-items: center; gap: 2px;">
            <input
              type="checkbox"
              checked={@regex}
              phx-click="search_toggle_filter"
              phx-value-filter="regex"
            /> Regex
          </label>
          <label style="display: flex; align-items: center; gap: 2px;">
            <input
              type="checkbox"
              checked={@my_mentions}
              phx-click="search_toggle_filter"
              phx-value-filter="my_mentions"
            /> My nick
          </label>
          <label style="display: flex; align-items: center; gap: 2px;">
            <input
              type="checkbox"
              checked={@history}
              phx-click="search_toggle_filter"
              phx-value-filter="history"
            /> History
          </label>
        </div>
      </div>
    </div>
    """
  end

  defp search_counter(_, 0), do: "No results"
  defp search_counter(current, total), do: "#{current} of #{total}"
end
