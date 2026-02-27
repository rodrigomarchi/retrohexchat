defmodule RetroHexChatWeb.ShowcaseLive.SearchBarPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.SearchBar
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Search Bar", active_page: "search-bar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Search Bar</h2>

      <.showcase_card
        title="Default"
        description="Search bar with query, result counter, navigation buttons, and filter checkboxes."
      >
        <.search_bar
          query="hello world"
          result_count={12}
          current_result={3}
          case_sensitive={true}
        />
      </.showcase_card>

      <.showcase_card
        title="Empty Search"
        description="Search bar with no query entered."
      >
        <.search_bar />
      </.showcase_card>

      <.showcase_card
        title="With All Filters"
        description="All filter checkboxes enabled."
      >
        <.search_bar
          query="@mention"
          result_count={2}
          current_result={1}
          case_sensitive={true}
          regex={true}
          mentions_only={true}
          search_history={true}
        />
        <.code_example>
          &lt;.search_bar
            query="@mention"
            result_count={2}
            current_result={1}
            case_sensitive={true}
            regex={true}
            mentions_only={true}
            search_history={true}
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
