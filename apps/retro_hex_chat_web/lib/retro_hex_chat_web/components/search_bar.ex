defmodule RetroHexChatWeb.Components.SearchBar do
  @moduledoc """
  Retro-styled search dialog with text input, Find Next/Prev buttons,
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
      class="search-bar window search-bar-floating"
    >
      <div class="title-bar u-py-2 u-px-4">
        <div class="title-bar-text u-text-sm">Find</div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="close_search"></button>
        </div>
      </div>
      <div class="window-body u-p-4">
        <div class="u-flex u-gap-4 u-items-center">
          <form phx-change="search_input" phx-submit="search_next" class="u-contents">
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Find..."
              autocomplete="off"
              class="u-flex-1 u-text-sm"
              phx-debounce="300"
              phx-keydown="search_navigate"
            />
          </form>
          <span :if={@error} class="search-error">{@error}</span>
          <span
            :if={!@error}
            class="u-text-sm u-text-nowrap u-text-center u-min-w-50"
          >
            {search_counter(@current_index, @result_count)}
          </span>
          <button
            type="button"
            phx-click="search_prev"
            disabled={@result_count == 0}
            class="btn-sm"
          >
            Prev
          </button>
          <button
            type="button"
            phx-click="search_next"
            disabled={@result_count == 0}
            class="btn-sm"
          >
            Next
          </button>
        </div>
        <div class="search-filters u-mt-4">
          <label>
            <input
              type="checkbox"
              checked={@case_sensitive}
              phx-click="search_toggle_filter"
              phx-value-filter="case_sensitive"
            /> Case
          </label>
          <label>
            <input
              type="checkbox"
              checked={@regex}
              phx-click="search_toggle_filter"
              phx-value-filter="regex"
            /> Regex
          </label>
          <label>
            <input
              type="checkbox"
              checked={@my_mentions}
              phx-click="search_toggle_filter"
              phx-value-filter="my_mentions"
            /> My nick
          </label>
          <label>
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
