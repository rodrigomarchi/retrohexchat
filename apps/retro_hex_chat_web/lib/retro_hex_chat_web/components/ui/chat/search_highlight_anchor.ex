defmodule RetroHexChatWeb.Components.UI.SearchHighlightAnchor do
  @moduledoc """
  The hidden anchor element for the `SearchHighlightHook`.

  The hook receives the search push events (`search_highlight` / `search_scroll_to`
  / `search_clear_highlights`), applies them to the `#chat-messages` DOM, and reports
  the live match count back. The anchor carries no visual content — it only needs to
  be always present in the DOM so the hook stays mounted. Lives here (a `components/ui`
  function component) so the raw `hidden` utility stays out of the `SearchBar`
  LiveComponent, which the CSS-consistency lint scans.
  """
  use RetroHexChatWeb.Component

  @doc "Renders the always-mounted, hidden anchor element for `SearchHighlightHook`."
  @spec search_highlight_anchor(map()) :: Phoenix.LiveView.Rendered.t()
  def search_highlight_anchor(assigns) do
    ~H"""
    <div id="search-highlight-hook" phx-hook="SearchHighlightHook" class="hidden"></div>
    """
  end
end
