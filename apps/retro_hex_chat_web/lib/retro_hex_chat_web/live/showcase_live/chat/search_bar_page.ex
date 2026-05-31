defmodule RetroHexChatWeb.ShowcaseLive.Chat.SearchBarPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.SearchBar
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: dgettext("showcase", "Search Bar"), active_page: "search-bar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Search Bar")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Default")}
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
        title={dgettext("showcase", "Empty Search")}
        description="Search bar with no query entered. Prev/Next buttons are disabled."
      >
        <.search_bar />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Zero Results")}
        description="Search bar with a query but no matches found. Navigation buttons disabled."
      >
        <.search_bar query="nonexistent_text_xyz" result_count={0} current_result={0} />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Regex Error")}
        description="Search bar with an invalid regex showing error message."
      >
        <.search_bar
          query="[unclosed"
          result_count={0}
          current_result={0}
          regex={true}
          error="Invalid regex: missing closing bracket"
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "With All Filters")}
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
          result_count=&#123;2&#125;
          current_result=&#123;1&#125;
          case_sensitive=&#123;true&#125;
          regex=&#123;true&#125;
          mentions_only=&#123;true&#125;
          search_history=&#123;true&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
