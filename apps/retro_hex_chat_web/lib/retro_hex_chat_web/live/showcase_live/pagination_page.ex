defmodule RetroHexChatWeb.ShowcaseLive.PaginationPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Pagination", active_page: "pagination", current_page: 3)}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page}, socket) do
    {:noreply, assign(socket, current_page: String.to_integer(page))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Pagination</h2>

      <.showcase_card
        title="Basic Pagination"
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
            Prev
          </.button>
          <.button
            :for={page <- 1..5}
            variant={if(page == @current_page, do: "default", else: "outline")}
            size="sm"
            phx-click="go-to-page"
            phx-value-page={page}
          >
            {page}
          </.button>
          <.button
            variant="outline"
            size="sm"
            disabled={@current_page == 5}
            phx-click="go-to-page"
            phx-value-page="5"
          >
            Next
          </.button>
        </nav>
        <p class="text-xs text-muted-foreground mt-2">Current page: {@current_page}</p>
        <.code_example>
          &lt;nav class="flex items-center gap-1"&gt;
          &lt;.button variant="outline" size="sm"&gt;Prev&lt;/.button&gt;
          &lt;.button :for=&#123;page &lt;- 1..5&#125;
          variant=&#123;if(page == @current_page, do: "default", else: "outline")&#125;
          size="sm"&gt;
          &#123;page&#125;
          &lt;/.button&gt;
          &lt;.button variant="outline" size="sm"&gt;Next&lt;/.button&gt;
          &lt;/nav&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="With Ellipsis" description="Pagination showing ellipsis for many pages.">
        <nav class="flex items-center gap-1">
          <.button variant="outline" size="sm">Prev</.button>
          <.button variant="default" size="sm">1</.button>
          <.button variant="outline" size="sm">2</.button>
          <.button variant="outline" size="sm">3</.button>
          <span class="px-2 text-sm text-muted-foreground">...</span>
          <.button variant="outline" size="sm">98</.button>
          <.button variant="outline" size="sm">99</.button>
          <.button variant="outline" size="sm">100</.button>
          <.button variant="outline" size="sm">Next</.button>
        </nav>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
