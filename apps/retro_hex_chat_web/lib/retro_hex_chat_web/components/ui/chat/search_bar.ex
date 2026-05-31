defmodule RetroHexChatWeb.Components.UI.SearchBar do
  @moduledoc """
  Search bar component for the showcase design system.

  Composed from window + input + button + checkbox primitives.
  Floating search window with Find input, Prev/Next buttons,
  result counter, and filter checkboxes.

  ## Usage

      <.search_bar
        query="hello"
        result_count={5}
        current_result={2}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Checkbox

  alias RetroHexChatWeb.Icons

  @doc "Renders the search bar floating window."
  attr :query, :string, default: ""
  attr :result_count, :integer, default: 0
  attr :current_result, :integer, default: 0
  attr :case_sensitive, :boolean, default: false
  attr :regex, :boolean, default: false
  attr :mentions_only, :boolean, default: false
  attr :search_history, :boolean, default: false
  attr :error, :string, default: nil, doc: "Regex validation error message"
  attr :visible, :boolean, default: true, doc: "Show/hide the search bar"
  attr :on_search, :any, default: nil, doc: "Search input change callback"
  attr :on_next, :any, default: nil, doc: "Next result callback"
  attr :on_prev, :any, default: nil, doc: "Previous result callback"
  attr :on_navigate, :any, default: nil, doc: "Keyboard navigation callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"
  attr :on_toggle_filter, :any, default: nil, doc: "Filter checkbox toggle callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec search_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def search_bar(assigns) do
    ~H"""
    <.window
      :if={@visible}
      class={classes(["w-full md:w-[360px]", @class])}
      data-testid="search-bar"
      {@rest}
    >
      <.window_title_bar title={gettext("Find")} controls={[:close]} on_close={@on_close}>
        <:icon><Icons.icon_btn_find class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 space-y-retro-8">
        <%!-- Search input row --%>
        <form class="flex items-center gap-retro-4" phx-change={@on_search} phx-submit={@on_search}>
          <.input
            type="text"
            id="search-bar-input"
            value={@query}
            placeholder={gettext("Find text...")}
            class="flex-1"
            name="query"
            phx-debounce="300"
            phx-mounted={JS.focus(to: "#search-bar-input")}
            phx-keydown={@on_navigate}
            data-testid="search-bar-input"
          />
          <span
            class="text-xs text-muted-foreground whitespace-nowrap"
            data-testid="search-bar-count"
          >
            {@current_result}/{@result_count}
          </span>
        </form>

        <%!-- Error message --%>
        <p :if={@error} class="text-xs text-error">{@error}</p>

        <%!-- Navigation buttons --%>
        <div class="flex gap-retro-4">
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_prev}
            disabled={@result_count == 0}
            data-testid="search-bar-prev"
          >
            <:icon><Icons.icon_btn_prev class="w-4 h-4" /></:icon>
            {gettext("Prev")}
          </.button>
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_next}
            disabled={@result_count == 0}
            data-testid="search-bar-next"
          >
            <:icon><Icons.icon_btn_next class="w-4 h-4" /></:icon>
            {gettext("Next")}
          </.button>
        </div>

        <%!-- Filter checkboxes --%>
        <div class="grid grid-cols-2 gap-retro-4">
          <label class="flex items-center gap-retro-4 text-xs cursor-pointer">
            <.checkbox
              name="case_sensitive"
              value={@case_sensitive}
              phx-click={@on_toggle_filter}
              phx-value-filter="case_sensitive"
              data-testid="search-bar-case-sensitive"
            /> {gettext("Case sensitive")}
          </label>
          <label class="flex items-center gap-retro-4 text-xs cursor-pointer">
            <.checkbox
              name="regex"
              value={@regex}
              phx-click={@on_toggle_filter}
              phx-value-filter="regex"
              data-testid="search-bar-regex"
            /> {gettext("Regex")}
          </label>
          <label class="flex items-center gap-retro-4 text-xs cursor-pointer">
            <.checkbox
              name="mentions"
              value={@mentions_only}
              phx-click={@on_toggle_filter}
              phx-value-filter="my_mentions"
              data-testid="search-bar-my-mentions"
            /> {gettext("My mentions")}
          </label>
          <label class="flex items-center gap-retro-4 text-xs cursor-pointer">
            <.checkbox
              name="history"
              value={@search_history}
              phx-click={@on_toggle_filter}
              phx-value-filter="history"
              data-testid="search-bar-history"
            /> {gettext("Search history")}
          </label>
        </div>
      </.window_body>
    </.window>
    """
  end
end
