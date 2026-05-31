defmodule RetroHexChatWeb.ShowcaseLive.Primitives.PaginationPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: gettext("Pagination"), active_page: "pagination", current_page: 3)}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page}, socket) do
    {:noreply, assign(socket, current_page: String.to_integer(page))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Pagination")}</h2>

      <.showcase_card
        title={gettext("Basic Pagination")}
        description="Simple page navigation with numbered buttons."
      >
        <nav class="flex items-center gap-1">
          <.button
            variant="outline"
            size="sm"
            disabled={@current_page == 1}
            phx-click="go-to-page"
            phx-value-page="1"
          >
            <:icon><Icons.icon_btn_prev /></:icon>
            {gettext("Prev")}
          </.button>
          <.button
            :for={page <- 1..5}
            variant={if(page == @current_page, do: "default", else: "outline")}
            size="sm"
            phx-click="go-to-page"
            phx-value-page={page}
          >
            <:icon><Icons.icon_btn_page /></:icon>
            {page}
          </.button>
          <.button
            variant="outline"
            size="sm"
            disabled={@current_page == 5}
            phx-click="go-to-page"
            phx-value-page="5"
          >
            <:icon><Icons.icon_btn_next /></:icon>
            {gettext("Next")}
          </.button>
        </nav>
        <p class="text-xs text-muted-foreground mt-2">{gettext("Current page:")} {@current_page}</p>
        <.code_example>
          &lt;.button variant="outline" size="sm"&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_prev /&gt;&lt;/:icon&gt;
          Prev
          &lt;/.button&gt;
          &lt;.button :for=&#123;page &lt;- 1..5&#125; size="sm"&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_page /&gt;&lt;/:icon&gt;
          &#123;page&#125;
          &lt;/.button&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("With Ellipsis")}
        description="Pagination showing ellipsis for many pages."
      >
        <nav class="flex items-center gap-1">
          <.button variant="outline" size="sm">
            <:icon><Icons.icon_btn_prev /></:icon>
            {gettext("Prev")}
          </.button>
          <.button variant="default" size="sm">
            <:icon><Icons.icon_btn_page /></:icon>
            1
          </.button>
          <.button variant="outline" size="sm">
            <:icon><Icons.icon_btn_page /></:icon>
            2
          </.button>
          <.button variant="outline" size="sm">
            <:icon><Icons.icon_btn_page /></:icon>
            3
          </.button>
          <span class="px-2 text-sm text-muted-foreground">...</span>
          <.button variant="outline" size="sm">
            <:icon><Icons.icon_btn_page /></:icon>
            98
          </.button>
          <.button variant="outline" size="sm">
            <:icon><Icons.icon_btn_page /></:icon>
            99
          </.button>
          <.button variant="outline" size="sm">
            <:icon><Icons.icon_btn_page /></:icon>
            100
          </.button>
          <.button variant="outline" size="sm">
            <:icon><Icons.icon_btn_next /></:icon>
            {gettext("Next")}
          </.button>
        </nav>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
