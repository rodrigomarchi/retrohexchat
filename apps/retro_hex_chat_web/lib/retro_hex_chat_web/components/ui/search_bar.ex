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
  attr :class, :string, default: nil
  attr :rest, :global

  @spec search_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def search_bar(assigns) do
    ~H"""
    <.window class={classes(["w-[360px]", @class])} {@rest}>
      <.window_title_bar title="Find" controls={[:close]}>
        <:icon><Icons.icon_btn_find class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 space-y-retro-8">
        <%!-- Search input row --%>
        <div class="flex items-center gap-retro-4">
          <.input type="text" value={@query} placeholder="Find text..." class="flex-1" />
          <span class="text-xs text-muted-foreground whitespace-nowrap">
            {@current_result}/{@result_count}
          </span>
        </div>

        <%!-- Navigation buttons --%>
        <div class="flex gap-retro-4">
          <.button size="sm" variant="outline">
            <:icon><Icons.icon_btn_prev class="w-4 h-4" /></:icon>
            Prev
          </.button>
          <.button size="sm" variant="outline">
            <:icon><Icons.icon_btn_next class="w-4 h-4" /></:icon>
            Next
          </.button>
        </div>

        <%!-- Filter checkboxes --%>
        <div class="grid grid-cols-2 gap-retro-4">
          <label class="flex items-center gap-retro-4 text-xs cursor-pointer">
            <.checkbox name="case_sensitive" value={@case_sensitive} />
            Case sensitive
          </label>
          <label class="flex items-center gap-retro-4 text-xs cursor-pointer">
            <.checkbox name="regex" value={@regex} />
            Regex
          </label>
          <label class="flex items-center gap-retro-4 text-xs cursor-pointer">
            <.checkbox name="mentions" value={@mentions_only} />
            Mentions only
          </label>
          <label class="flex items-center gap-retro-4 text-xs cursor-pointer">
            <.checkbox name="history" value={@search_history} />
            Search history
          </label>
        </div>
      </.window_body>
    </.window>
    """
  end
end
