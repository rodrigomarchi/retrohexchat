defmodule RetroHexChatWeb.ShowcaseLive.Chat.HistorySearchPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.HistorySearch
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "History Search"),
       active_page: "history-search"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "History Search")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Visible")}
        description="Search bar shown when the user activates history search mode."
      >
        <.history_search visible={true} />
        <.code_example>
          &lt;.history_search visible={true} /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Hidden")}
        description="Nothing rendered when visible is false."
      >
        <div class="shadow-retro-field bg-white p-3 min-h-[40px] flex items-center justify-center">
          <span class="text-xs text-muted-foreground">
            {dgettext("showcase", "(empty — history_search renders nothing)")}
          </span>
        </div>
        <.history_search visible={false} />
        <.code_example>
          &lt;.history_search visible={false} /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
