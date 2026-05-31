defmodule RetroHexChatWeb.Components.UI.HistorySearch do
  @moduledoc """
  Client-side history search bar for the showcase design system.

  A retro-styled search input used to filter chat history. Includes a
  "No results" indicator when visible and no matches are found.

  ## Usage

      <.history_search visible={true} />
      <.history_search visible={false} />
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc "Renders a history search bar with optional no-results indicator."
  attr :id, :string, default: "hist-search-panel"
  attr :visible, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  @spec history_search(map()) :: Phoenix.LiveView.Rendered.t()
  def history_search(assigns) do
    ~H"""
    <div
      :if={@visible}
      id={@id}
      class={
        classes([
          "flex items-center gap-retro-4 px-retro-8 py-retro-4 bg-surface border-b border-border",
          @class
        ])
      }
      data-testid="history-search"
      {@rest}
    >
      <Icons.icon_btn_find class="w-[16px] h-[16px] shrink-0 text-muted-foreground" />
      <input
        type="text"
        placeholder={gettext("Search history...")}
        class="history-search-input flex-1 shadow-retro-field bg-white px-retro-4 py-retro-2 text-xs text-foreground placeholder:text-muted-foreground focus:outline-none"
        aria-label={gettext("Search chat history")}
        data-testid="history-search-input"
      />
      <span
        class="history-no-match u-hidden text-xs text-muted-foreground whitespace-nowrap"
        data-testid="history-search-no-results"
      >
        {gettext("No results")}
      </span>
    </div>
    """
  end
end
